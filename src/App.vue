<template>
    <div class="right">
        <select :disabled="walletConnected" v-model="selectedNetwork">
            <option>mainnet-beta</option>
            <option>testnet</option>
            <option>devnet</option>
            <option>localhost</option>
            <option>fortuna</option>
        </select>

        <!-- ill use the wallet adapter if someone tells me how to make the ui stuff look like 1995 -->
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
                let bal = await this.connection.getBalance(this.wallet.publicKey);
                this.solBalance = (bal / 10 ** 9).toFixed(3);
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
