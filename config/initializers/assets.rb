# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
# 1.1: PR #207のabout.scss変更が本番のassets:precompileで反映されず、9/20時点の
# application.cssが配信され続けたため、Sprocketsのキャッシュを無効化する。
Rails.application.config.assets.version = '1.1'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )
