# =========================================
# Puma configuration file for production
# =========================================

app_dir     = File.expand_path('../..', __FILE__)
tmp_dir     = "#{app_dir}/tmp"
log_dir     = "#{app_dir}/log"
rails_env   = ENV.fetch("RAILS_ENV", "production")

# Pumaの実行環境
environment rails_env

# ソケット通信（Nginx連携）
bind "unix://#{tmp_dir}/sockets/puma.sock"

# プロセス管理
pidfile     "#{tmp_dir}/pids/puma.pid"
state_path  "#{tmp_dir}/pids/puma.state"

# ログ出力
stdout_redirect "#{log_dir}/puma.stdout.log", "#{log_dir}/puma.stderr.log", true

# ワーカーモード（Cluster）
workers      ENV.fetch("WEB_CONCURRENCY", 2)
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5).to_i
threads threads_count, threads_count

preload_app!

# 再起動サポート
plugin :tmp_restart

# 起動前処理（DB接続をクリーンに）
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

# pumactl用のソケット（オプション）
activate_control_app "unix://#{tmp_dir}/sockets/pumactl.sock"

# デーモン化（※systemdで起動管理するならコメントアウトかfalse）
# daemonize true if rails_env == 'production'
