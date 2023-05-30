const { environment } = require('@rails/webpacker')

const webpack = require('webpack');
environment.plugins.append('Provide', new webpack.ProvidePlugin({
  $:      require.resolve("jquery"),
  jQuery: require.resolve("jquery")
}))

module.exports = environment
