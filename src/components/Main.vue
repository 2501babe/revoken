<template>
<div class="right">
    <select :disabled="walletConnected" v-model="selectedNetwork">
        <option>mainnet-beta</option>
        <option>testnet</option>
        <option>devnet</option>
        <option>localhost</option>
    </select>

    <span v-if="walletConnected">
        <button @click="wallet.disconnect()">disconnect</button>
    </span>
    <span v-else>
        <button @click="connectWallet()">connect</button>
    </span>

    <div>
        <span v-if="walletConnected">
            <Address :pubkey="wallet.publicKey"/>| {{ solBalance == null ? "--" : solBalance }} sol
        </span>
        <span v-else>
            <input type="radio" id="sollet-rad" value="sollet" v-model="walletChoice"/>
            <label for="sollet-rad">sollet</label>
            <input type="radio" id="phantom-rad" value="phantom" v-model="walletChoice"/>
            <label for="phantom-rad">phantom</label>
        </span>
        <br/>
    </div>
</div>

<h1>solana token revoken</h1>

<div v-if="tokens === null">
    <p>
        the spl token program has an instruction called approve.
        approve is intended to function similar the ierc20 function of the same name:
        instead of signing a token account away to a program to modify as it pleases,
        you independently grant it a maximum budget it can use without further authorization
    </p>

    <div class="center">
        <img src="https://media.githubusercontent.com/media/2501babe/2501babe.github.io/master/img/hana-revoken-tweet.png"
             alt="tiny brain: malicious solana program that rugs people who call it.
                  giant dick: malicious solana program that tags people who call it
                  with approvals and then rugs everyone all at once months later
        "/>
    </div>

    <p>
        but thanks to how crossprogram calling works in solana this can actually be used against you.
        if you sign for a token account to a malicious program, it can call into the token program and
        use your signature to approve itself to withdraw an unlimited amount of that token at an arbitrary later date
    </p>

    <p>
        to be clear it could also just steal your tokens then and there.
        but a program may want to use approvals to a) fly under the radar for some time to massively increase its take,
        and b) fool phantoms new balance change simulator by not actually changing balances in the transaction you sign.
        this would be a really cool attack and would scare a lot of people i think
    </p>

    <p>
        this is all because of another interesting ("interesting") difference between solana and ethereum.
        on ethereum, erc20 transfer always uses msg.sender as the token sender.
        it is not possible for a contract to avoid the twolegged approve and  transferFrom flow.
        but on solana, theres only transfer, gated by either a wallet signature or an approval.
        crossprogram calls pass the hash so to speak, and programs cannot distinguish an intermediary from an origin
    </p>

    <p>
        anyway!! this is a client app that pulls your token accounts, checks for active approvals, 
        and creates and sends transactions to revoke them at your pleasure
    </p>

    <p>
        code available <a href="https://github.com/2501babe/revoken">here</a>
    </p>

    <div class="center">
        <button :disabled="!walletConnected" @click="fetchTokens()">lets do it</button>
    </div>
</div>
<div v-else-if="tokens === undefined">
    <p>something happened</p>
</div>
<div v-else-if="tokens.length == 0">
    <div class="center">
        <img src="https://media.githubusercontent.com/media/2501babe/2501babe.github.io/master/img/makima-chain.jpg"/>
    </div>
    <p>congrats! youre safe. isnt that what youve always wanted to hear?</p>
</div>
<div v-else>
    <table class="token-table">
        <tr>
            <th/>
            <th>token</th>
            <th>account address</th>
            <th>mint address</th>
            <th>delegate address</th>
            <th>approved amount</th>
        </tr>
        <tr v-for="token in tokens" :key="token.address.toString()">
            <td class="button-swap">
                <span v-if="token.revokeStatus == 'open'">
                    <button @click="revoke(token)">revoke</button>
                </span>
                <span v-else-if="token.revokeStatus == 'pending'">
                    <Dots/>
                </span>
                <span v-else-if="token.revokeStatus == 'closed'">
                    <strong>&check;</strong>
                </span>
            </td>
            <td>
                <div class="token-info">
                    <img v-if="token.meta?.logoURI" :src="token.meta.logoURI" />
                    <div>
                        <a v-if="token.meta?.extensions?.website" :href="token.meta.extensions.website">
                            {{ token.meta.name }}
                        </a>
                        <span v-if="token.meta?.symbol">
                            {{ token.meta.symbol }}
                        </span>
                    </div>
                </div>
            </td>
            <td><Address :pubkey="token.address"/></td>
            <td><Address :pubkey="token.mint"/></td>
            <td>
                <span v-if="token.delegate">
                    <Address :pubkey="token.delegate"/>
                </span>
                <span v-else>--</span>
            </td>
            <td>
                {{ token.meta.formattedDelegatedAmount }}
                <span class="usd-total" v-if="token?.meta?.usdFormattedTotal">
                    {{ token.meta.usdFormattedTotal }}
                </span>
            </td>
        </tr>
    </table>
</div>

<p class="center"><a href="/index.html">home</a></p>
</template>

<script>
import * as w3 from "@solana/web3.js";
import { TOKEN_PROGRAM_ID, Token, AccountLayout, u64 } from "@solana/spl-token";
import { PhantomWalletAdapter } from "@solana/wallet-adapter-phantom";
import { SolletWalletAdapter } from "@solana/wallet-adapter-sollet";
import { shallowRef } from 'vue';
import Dots from "./Dots.vue";
import Address from "./Address.vue";

const NETWORKS = {
    "mainnet-beta": {
        url: "https://solana-api.projectserum.com",
        tokenlistChainId: 101
    },
    testnet: {
        url: "https://api.testnet.solana.com",
        tokenlistChainId: 102
    },
    devnet: {
        url: "https://api.devnet.solana.com",
        tokenlistChainId: 103
    },
    localhost: {
        url: "http://127.0.0.1:8899"
    },
};

export default {
    name: "Main",
    components: {
        Dots,
        Address,
    },
    mounted() {
        let vm = window.revoken = this;
        vm.connectChain();
    },
    data() {
        return {
            connection: null,
            wallet: shallowRef(null),
            walletConnected: false,
            walletChoice: "phantom",
            solBalance: null,
            selectedNetwork: "mainnet-beta",
            tokens: null,
        }
    },
    watch: {
        selectedNetwork(curr, prev) {
            if(curr != prev) {
                this.connectChain();
            }
        }
    },
    methods: {
        async connectWallet() {
            let vm = this;

            switch(vm.walletChoice) {
                case "sollet":
                    vm.wallet = new SolletWalletAdapter({provider: "https://www.sollet.io", network: vm.selectedNetwork});
                    break;
                case "phantom":
                    vm.wallet = new PhantomWalletAdapter();
                    break;
                default:
                    console.error("missed a case", this.walletChoice);
                    return;
            }

            vm.wallet.on("connect", () => {
                vm.walletConnected = true;
                vm.fetchBalance();
            });

            vm.wallet.on("disconnect", () => {
                vm.wallet = null;
                vm.walletConnected = false;
                vm.solBalance = null;
                vm.tokens = null;
            });

            await vm.wallet.connect();
        },
        connectChain() {
            this.connection = new w3.Connection(NETWORKS[this.selectedNetwork].url);
        },
        parseTokenAccount(address, account) {
            let accountInfo = AccountLayout.decode(account.data);

            // no need to waste cycles
            // XXX remember to remove if i use this function elsewhere
            if(accountInfo.delegateOption === 0) return null;
            else accountInfo.revokeStatus = "open";

            accountInfo.address = address;
            accountInfo.mint = new w3.PublicKey(accountInfo.mint);
            accountInfo.owner = new w3.PublicKey(accountInfo.owner);
            accountInfo.amount = u64.fromBuffer(accountInfo.amount);

            if(accountInfo.delegateOption === 0) {
                accountInfo.delegate = null;
                accountInfo.delegatedAmount = new u64();
            } else {
                accountInfo.delegate = new w3.PublicKey(accountInfo.delegate);
                accountInfo.delegatedAmount = u64.fromBuffer(accountInfo.delegatedAmount);
            }

            accountInfo.isInitialized = accountInfo.state !== 0;
            accountInfo.isFrozen = accountInfo.state === 2;

            if(accountInfo.isNativeOption === 1) {
                accountInfo.rentExemptReserve = u64.fromBuffer(accountInfo.isNative);
                accountInfo.isNative = true;
            } else {
                accountInfo.rentExemptReserve = null;
                accountInfo.isNative = false;
            }

            if(accountInfo.closeAuthorityOption === 0) {
                accountInfo.closeAuthority = null;
            } else {
                accountInfo.closeAuthority = new w3.PublicKey(accountInfo.closeAuthority);
            }

            return accountInfo;
        },
        async fetchBalance() {
            this.solBalance = await
                this.connection.getBalance(this.wallet.publicKey)
                .then(bal => (bal / 10 ** 9).toFixed(3))
                .catch(() => null);
        },
        async fetchTokens() {
            let vm = this;

            const [{ tokens }, tokenAccounts] = await Promise.all([
                fetch("https://raw.githack.com/solana-labs/token-list/main/src/tokens/solana.tokenlist.json")
                    .then(x => x.json()),

                vm.connection.getTokenAccountsByOwner(
                    vm.wallet.publicKey,
                    { programId: TOKEN_PROGRAM_ID }
                )
            ]);

            // get all tokens for this wallet, parse them, and filter those without delegates
            // i short circuit in the parser when this is the case
            this.tokens = tokenAccounts.value.map(v => vm.parseTokenAccount(v.pubkey, v.account))
                            .filter(Boolean)
                            .map(token => ({
                                ...token,
                                meta: tokens.find(t =>
                                    t.chainId === NETWORKS[this.selectedNetwork].tokenlistChainId &&
                                    t.address === token.mint.toString()
                                )
                            }));

            const coingeckoIds = this.tokens.map(t => t.meta?.extensions?.coingeckoId).filter(Boolean);

            if (coingeckoIds.length > 0) {
                const url = `https://api.coingecko.com/api/v3/simple/price?ids=${coingeckoIds.join(",")}&vs_currencies=usd`
                const res = await fetch(url);
                const json = await res.json();
                Object.entries(json).forEach(([id, { usd }]) => {
                    const token = this.tokens.find(t => t.meta?.extensions?.coingeckoId === id);
                    token.meta.usd = usd;
                    if (token.meta.decimals) {
                        token.meta.formattedDelegatedAmount = token.delegatedAmount  / (10 ** token.meta.decimals);
                        token.meta.usdFormattedTotal = new Intl.NumberFormat(
                                'en-US',
                                { style: 'currency', currency: 'USD'}
                            ).format(token.meta.formattedDelegatedAmount * token.meta.usd)
                    } else {
                        token.meta.formattedDelegatedAmount = `${token.delegatedAmount} (unknown decimals)`
                    }
                })
            }

        },
        async revoke(token) {
            let txn = new w3.Transaction();
            txn.add(
                Token.createRevokeInstruction(
                    TOKEN_PROGRAM_ID,
                    token.address,
                    this.wallet.publicKey,
                    []
                )
            );
            txn.feePayer = this.wallet.publicKey;
            txn.recentBlockhash = (await this.connection.getRecentBlockhash()).blockhash

            let signed = await this.wallet.signTransaction(txn);
            let sig = await this.connection.sendRawTransaction(signed.serialize());
            token.revokeStatus = "pending";

            await this.connection.confirmTransaction(sig);
            token.revokeStatus = "closed";
            token.delegate = null;
            token.delegatedAmount = 0;
        }
    }
}
</script>

<style>
#app {
    margin: 40px auto;
    max-width: 800px;
    font: 18px/1.5 sans-serif;
    padding: 0 10px;
}

h1, h2, h3 {
    line-height: 1.2;
    text-align: center;
}

img {
    max-width: 100%;
    height: auto;
}

.center {
    text-align: center;
}

.right {
    text-align: right;
}

.token-table {
    font: 14px/1.2 sans-serif;
}

.token-info {
    display: flex;
    line-height: 1.5;
}

.token-info img {
    width: 45px;
    height: 45px;
    border-radius: 45px;
    margin: 0 5px;
}

.token-info > div {
    flex: 1;
}

.token-info a {
    display: block;
}

span.usd-total {
    display: block;
    text-decoration: italic;
    color: #888;
}

button, select {
    cursor: pointer;
}

button:disabled, select:disabled {
    cursor: not-allowed;
}

.button-swap {
    text-align: center;
    display: inline-block;
    width: 2.5em;
    height: 1.2em;
    margin: 10px;
}

td, th {
    padding: 0 10px;
    text-align: left;
}

code {
    font-family: monospace;
    background-color: #eee;
}
</style>
