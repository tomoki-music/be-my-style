# =========================================
# Puma configuration for Rails 6.1
# =========================================

# 環境の取得（development / production など）
rails_env = ENV.fetch("RAILS_ENV") { "development" }
environment rails_env

# スレッド数
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
threads threads_count, threads_count

# ワーカープロセス数（Herokuや本番向け）
workers ENV.fetch("WEB_CONCURRENCY", 2)

# preload_appはCluster構成で必須
preload_app!

if rails_env == "development"
  # 🔧 開発環境：ポート3000で起動
  port ENV.fetch("PORT") { 3000 }
else
  # 🚀 本番環境：UNIXソケットでバインド
  app_dir = File.expand_path('../..', __FILE__)
  tmp_dir = "#{app_dir}/tmp"
  log_dir = "#{app_dir}/log"

  bind "unix:///run/puma/puma.sock"
  pidfile "#{tmp_dir}/pids/puma.pid"
  state_path "#{tmp_dir}/pids/puma.state"

  stdout_redirect "#{log_dir}/puma.stdout.log", "#{log_dir}/puma.stderr.log", true

  # pumactlを使う場合はこちら（任意）
  activate_control_app "unix:///run/puma/pumactl.sock"
end

# プロセスフォーク前後のDB接続管理
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# tmp/restart.txt により再起動可能にする
plugin :tmp_restart
