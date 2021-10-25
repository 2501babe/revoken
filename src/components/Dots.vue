<template>
    <span>{{ dots }}</span>
</template>

<script>
export default {
    name: "Dots",
    mounted() {
        let vm = this;

        let loop = setInterval(() => {
            if(vm.dots == "") vm.dots = ".";
            else if(vm.dots == ". . .") vm.dots = "";
            else vm.dots = vm.dots + " .";
        }, 500);
    },
    data() {
        return {
            dots: "",
        }
    },
}
</script>
