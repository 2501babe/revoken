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

    <div>
        <p>
            the spl token program has an instruction called approve.
            approve is intended to function similar the ierc20 function of the same name:
            instead of signing a token account away to a program to modify as it pleases,
            you independently grant it a maximum budget it can use without further authorization
        </p>

        <div class="center"><img src="/hana-tweet.png"/></div>

        <p>
            but thanks to how cross program calling works in solana this can actually be used against you.
            if you sign for a token account to a malicious program, it can tag you with an approve instruction
            and withdraw funds at an arbitrary later date
        </p>

        <p>
            to be clear it could also just steal your tokens then and there.
            but a program may want to use approvals a) to fly under the radar for some time to massively increase its take,
            and b) to fool phantoms new balance change simulator by not actually changing balances in the transaction you sign.
            this would be a really cool attack and would scare a lot of people i think
        </p>

        <p>
            this is all because of another interesting ("interesting") difference between solana and ethereum.
            on ethereum, erc20 transfer always uses msg.sender as the token sender.
            it is not possible for a contract to avoid the two legged approve and  transferFrom flow.
            but on solana, theres only transfer. gated by either a signature by the wallet pubkey or an approval
            cross program calls pass the hash so to speak, and programs cannot distinguish an intermediary from an origin
        </p>

        <p>
            anyway!! this is a clientside app that pulls your token accounts, checks for active approvals, 
            and creates and sends transactions to revoke them at your pleasure
        </p>

        <div class="center">
            <button :disabled="!walletConnected">lets do it</button>
        </div>
    </div>

    <p class="center"><a href="/index.html">home</a></p>
</template>

<script>
    import * as w3 from "../node_modules/@solana/web3.js";
    import { TOKEN_PROGRAM_ID, Token } from "../node_modules/@solana/spl-token";

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
                selectedNetwork: "fortuna",
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
            async fetchBalance() {
                this.solBalance = await
                    this.connection.getBalance(this.wallet.publicKey)
                    .then(bal => (bal / 10 ** 9).toFixed(3))
                    .catch(() => null);
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
