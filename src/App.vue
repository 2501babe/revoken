<template>
    <div class="right">
        <select :disabled="walletConnected" v-model="selectedNetwork">
            <option>mainnet-beta</option>
            <option>testnet</option>
            <option>devnet</option>
            <option>localhost</option>
            <option>fortuna</option>
        </select>

        <span v-if="walletConnected">
            <button @click="wallet.disconnect()">disconnect</button>
        </span>
        <span v-else-if="wallet && !phantom">
            <button :disabled="true">phantom only sorry</button>
        </span>
        <span v-else>
            <button :disabled="!wallet" @click="wallet.connect()">connect</button>
        </span>

        <div>
            <span v-show="walletConnected">
                {{ prettyKey }} | {{ solBalance == null ? "--" : solBalance }} sol
            </span>
            <br/>
        </div>
    </div>

    <h1>solana token revoken</h1>

    <div v-if="tokens == null">
        <p>
            the spl token program has an instruction called approve.
            approve is intended to function similar the ierc20 function of the same name:
            instead of signing a token account away to a program to modify as it pleases,
            you independently grant it a maximum budget it can use without further authorization
        </p>

        <div class="center"><img src="/hana-tweet.png"/></div>

        <p>
            but thanks to how cross program calling works in solana this can actually be used against you.
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
            it is not possible for a contract to avoid the two legged approve and  transferFrom flow.
            but on solana, theres only transfer, gated by either a wallet signature or an approval.
            cross program calls pass the hash so to speak, and programs cannot distinguish an intermediary from an origin
        </p>

        <p>
            anyway!! this is a client app that pulls your token accounts, checks for active approvals, 
            and creates and sends transactions to revoke them at your pleasure
        </p>

        <div class="center">
            <button :disabled="!walletConnected" @click="fetchTokens()">lets do it</button>
        </div>
    </div>
    <div v-else-if="tokens.length == 0">
        <p>you have no open approvals. congrats! youre safe. isnt that what youve always wanted to hear?</p>
    </div>
    <div v-else>
    </div>

    <p class="center"><a href="/index.html">home</a></p>
</template>

<script>
    import * as w3 from "../node_modules/@solana/web3.js";
    import { TOKEN_PROGRAM_ID, AccountLayout, u64 } from "../node_modules/@solana/spl-token";

    const NETWORKS = {
        "mainnet-beta": "https://solana-api.projectserum.com",
        testnet: "https://api.testnet.solana.com",
        devnet: "https://api.devnet.solana.com",
        localhost: "http://127.0.0.1:8899",
        fortuna: "http://fortuna:8899",
    };

    export default {
        name: "App",
        mounted() {
            let vm = window.revoken = this;

            let walletLoop = setInterval(() => {
                if(window.solana) {
                    vm.wallet = window.solana;

                    window.solana.on("connect", () => {
                        vm.walletConnected = true;
                        vm.fetchBalance();
                    });

                    window.solana.on("disconnect", () => {
                        vm.walletConnected = false;
                        vm.solBalance = null;
                    });

                    clearInterval(walletLoop);
                }
            }, 100);

            vm.connectChain();
        },
        data() {
            return {
                connection: null,
                wallet: null,
                walletConnected: false,
                solBalance: null,
                selectedNetwork: "testnet",
                tokens: null,
            }
        },
        computed: {
            prettyKey() {
                if(!this.walletConnected) return "";

                let pubkey = this.wallet.publicKey.toString();
                return pubkey.substring(0, 4) + "..." + pubkey.substring(pubkey.length - 4);
            },
            phantom() {
                return !!(this.wallet && this.wallet.isPhantom);
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
            connectChain() {
                this.connection = new w3.Connection(NETWORKS[this.selectedNetwork]);
            },
            parseTokenAccount(address, account) {
                let accountInfo = AccountLayout.decode(account.data);

                accountInfo.address = address;
                accountInfo.mint = new w3.PublicKey(accountInfo.mint);
                accountInfo.owner = new w3.PublicKey(accountInfo.owner);
                accountInfo.amount = u64.fromBuffer(accountInfo.amount);

                console.log("HANA ai:", accountInfo);

                if (accountInfo.delegateOption === 0) {
                    accountInfo.delegate = null;
                    accountInfo.delegatedAmount = new u64();
                } else {
                    accountInfo.delegate = new w3.PublicKey(accountInfo.delegate);
                    accountInfo.delegatedAmount = u64.fromBuffer(accountInfo.delegatedAmount);
                }

                accountInfo.isInitialized = accountInfo.state !== 0;
                accountInfo.isFrozen = accountInfo.state === 2;

                if (accountInfo.isNativeOption === 1) {
                    accountInfo.rentExemptReserve = u64.fromBuffer(accountInfo.isNative);
                    accountInfo.isNative = true;
                } else {
                    accountInfo.rentExemptReserve = null;
                    accountInfo.isNative = false;
                }

                if (accountInfo.closeAuthorityOption === 0) {
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
                // XXX ok tomorrow this works
                // filter to only with delegate
                // i can use command line to approve so this is easy to test
                // so then... render the filtered results with v-for
                // tick boxes, token info if it exists in the registry
                // button on the bottom of the form and then build our transactions
                // orrr nah actually. just put revoke buttons next to every token
                // that way i dont have to worry about batching logic
                let x = await this.connection.getTokenAccountsByOwner(this.wallet.publicKey, { programId: TOKEN_PROGRAM_ID });
                let tok = x.value[0];
                console.log("HANA tok:", tok);
                let acct = this.parseTokenAccount(tok.pubkey, tok.account);
                console.log("HANA acct:", acct);
                this.tokens = [];
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

.center {
    text-align: center;
}

.right {
    text-align: right;
}

code {
    font-family: monospace;
    background-color: #eee;
}
</style>
