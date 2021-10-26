module.exports = {
    publicPath: "./",
    css: {
        extract: false,
    },
    configureWebpack: {
        optimization: {
            splitChunks: false
        }
    },
};
