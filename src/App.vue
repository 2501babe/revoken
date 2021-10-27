<script setup>
import { WalletProvider } from '@solana/wallet-adapter-vue';
import { getPhantomWallet, getSolletWallet } from '@solana/wallet-adapter-wallets';
import Main from "./components/Main.vue";

const wallets = [getPhantomWallet(), getSolletWallet()];
</script>

<template>
    <WalletProvider :wallets="wallets">
        <Main/>
    </WalletProvider>
</template>
