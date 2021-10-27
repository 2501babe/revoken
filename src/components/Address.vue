<template>
    <span class="tooltip">
        <span class="tooltiptext" :class="{active: copyTooltip}">copied!</span>
        <button :title="address" @click="copy">{{ pretty() }}</button>
    </span>
</template>

<script>
export default {
    name: "Address",
    props: {
        pubkey: Object,
    },
    data() {
        return {
            copyTooltip: 0,
        }
    },
    computed: {
        address() {
            return this.pubkey ? this.pubkey.toString() : "";
        },
    },
    methods: {
        pretty() {
            return this.address.substring(0, 4) + "..." + this.address.substring(this.address.length - 4);
        },
        async copy() {
            await navigator.clipboard.writeText(this.address);
            this.copyTooltip += 1;
            setTimeout(() => this.copyTooltip -= 1, 2000);
        }
    },
}
</script>

<style scoped>
button {
    font: inherit;
    background: none;
    border: none;
}

.tooltip {
  position: relative;
  display: inline-block;
}

.tooltiptext {
  font: 14px/1.2 sans-serif;
  visibility: hidden;
  text-align: center;
  color: white;
  background: black;
  padding: 5px;
  position: absolute;
  z-index: 1;
  bottom: 1.5em;
  left: 1em;
}

.tooltiptext.active {
    visibility: visible;
}
</style>
