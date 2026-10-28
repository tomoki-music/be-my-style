# Business スレッド・参加承認のマイグレーション(20261027000000〜000300)を、使い捨ての MySQL で検証する。
# 本番・開発の DB には使わない。指定したサーバーに専用の DB を2つ作り、終了時に削除する。
#
#   CHECK_MYSQL_HOST=127.0.0.1 CHECK_MYSQL_PORT=3307 CHECK_MYSQL_USER=root CONFIRM_DISPOSABLE=yes \
#     RAILS_ENV=test bundle exec rails runner script/business_migration_mysql_check.rb
#
# 確認内容: 通常移行(本番と同じ main 時点のスキーマ + 旧データから) / db/schema.rb とのスキーマ一致 /
# 一意制約・外部キー・NULL 許容 / 途中失敗(7か所)後の再実行 / ロック待ちの時間切れと再実行 / サーバー全体の設定が不変。
# MySQL 8.4 以外では止まる(ALLOW_NON_84=1 で手順そのものの確認用に実行できる)。
require "open3"
require "stringio"

module BusinessMigrationMysqlCheck
  # 本番に適用済みのスキーマ(schema version 20261018000000)を持つ main のコミット。
  BASE_COMMIT = "8acf938f".freeze
  DB = "bms_migration_check_tmp".freeze
  REF_DB = "bms_migration_check_ref_tmp".freeze
  MIGRATIONS = Rails.root.join("db/migrate").to_s
  VERSIONS = %w[20261027000000 20261027000100 20261027000200 20261027000300].freeze

  class InjectedFailure < StandardError; end

  module Hooks
    class << self
      attr_accessor :fail_at, :seen, :before_chats_column, :after_chats_fk
    end

    def add_column(table, column, type, **options)
      Hooks.seen ||= select_rows("SELECT @@SESSION.lock_wait_timeout, @@SESSION.innodb_lock_wait_timeout").first.map(&:to_i)
      raise InjectedFailure if Hooks.fail_at == [:add_column, table.to_sym, column.to_sym]
      Hooks.before_chats_column&.call if table.to_s == "project_chats"
      super
    end

    def change_column_default(table, column, default_or_changes)
      raise InjectedFailure if Hooks.fail_at == [:change_column_default, table.to_sym, column.to_sym]
      super
    end

    def add_index(table, columns, **options)
      raise InjectedFailure if Hooks.fail_at == [:add_index, table.to_sym, Array(columns).map(&:to_sym)]
      super
    end

    def add_foreign_key(from, to, **options)
      raise InjectedFailure if Hooks.fail_at == [:add_foreign_key, from.to_sym, to.to_sym]
      result = super
      Hooks.after_chats_fk&.call if from.to_s == "project_chats" && to.to_s == "project_threads"
      result
    end
  end

  # 全体トーク作成ループの途中失敗用
  module ThreadCreateHook
    class << self
      attr_accessor :fail_on_call, :calls
    end

    def create!(*args, **kwargs, &block)
      ThreadCreateHook.calls = ThreadCreateHook.calls.to_i + 1
      raise InjectedFailure if ThreadCreateHook.calls == ThreadCreateHook.fail_on_call
      super
    end
  end

  FAILURE_POINTS = {
    "1本目: communities の列追加後、projects の列追加で失敗" => [:add_column, :projects, :join_approval_mode],
    "1本目: projects の列追加後、既定値の変更で失敗" => [:change_column_default, :projects, :join_approval_mode],
    "2本目: project_join_requests の作成後、一意索引で失敗" => [:add_index, :project_join_requests, %i[project_id customer_id]],
    "3本目: project_threads の作成後、(project_id, general) 一意索引で失敗" => [:add_index, :project_threads, %i[project_id general]],
    "3本目: project_chats の列追加後、索引作成で失敗" => [:add_index, :project_chats, [:project_thread_id]],
    "3本目: project_chats の列・索引追加後、外部キー作成で失敗" => [:add_foreign_key, :project_chats, :project_threads],
  }.freeze

  module_function

  def run
    guard!
    run_checks
  ensure
    cleanup!
  end

  def run_checks
    results = []
    check = lambda do |name, ok, detail = nil|
      results << ok
      puts "#{ok ? 'OK' : 'NG'}  #{name}#{detail ? "  (#{detail})" : ''}"
    end

    server.execute("CREATE DATABASE #{DB} CHARACTER SET utf8mb4")
    server.execute("CREATE DATABASE #{REF_DB} CHARACTER SET utf8mb4")
    @created = true
    globals_before = global_timeouts
    puts "MySQL #{server.select_value('SELECT VERSION()')} / 起点 #{BASE_COMMIT} / 対象 #{VERSIONS.join(', ')}"

    # 1. 通常移行
    fresh_db!
    session_before = session_timeouts
    error, = try_migrate
    baseline = snapshot
    check.call("通常移行: 4本とも成功", error.nil? && applied == VERSIONS, error && describe(error))
    check.call("通常移行: 実行中だけロック待ち上限 5秒/10秒、終了後は元の値", Hooks.seen == [5, 10] && session_timeouts == session_before, "#{Hooks.seen.inspect} 後=#{session_timeouts.inspect}")
    check.call("通常移行: 全体トークが各プロジェクトに1つ・既存チャットは全件紐づけ", baseline[:threads].map(&:first) == [1, 2, 3] && baseline[:chats].all? { |_, linked| linked == 1 })
    check.call("通常移行: 参加方式 既存コミュニティ=手動(0)・既存プロジェクト=自動(1)", baseline[:modes] == [["c", 1, 0], ["p", 1, 1], ["p", 2, 1], ["p", 3, 1]], baseline[:modes].inspect)

    # 2. スキーマ一致(同じサーバーで db/schema.rb を読み込んだ DB と比べる)
    check.call("スキーマ: マイグレーション結果が db/schema.rb と一致", baseline[:schema] == reference_schema, "差分は #{DB}.schema / #{REF_DB}.schema を SchemaDumper で比較")

    # 3. 制約
    constraint_checks.each { |name, ok| check.call("制約: #{name}", ok) }

    # 4. 途中失敗 → 再実行
    FAILURE_POINTS.each do |label, point|
      fresh_db!
      Hooks.fail_at = point
      first, = try_migrate
      Hooks.fail_at = nil
      rerun, = try_migrate
      check.call("途中失敗→再実行: #{label}", first.is_a?(InjectedFailure) && rerun.nil? && snapshot == baseline, rerun && describe(rerun))
    end

    fresh_db!
    load_migration_classes
    CreateProjectThreads::MigrationProjectThread.singleton_class.prepend(ThreadCreateHook)
    ThreadCreateHook.calls = 0
    ThreadCreateHook.fail_on_call = 2
    first, = try_migrate
    ThreadCreateHook.fail_on_call = nil
    partial = connection.select_value("SELECT COUNT(*) FROM project_threads").to_i
    rerun, = try_migrate
    check.call("途中失敗→再実行: 3本目: 全体トーク1件作成後、2件目で失敗", first.is_a?(InjectedFailure) && partial == 1 && rerun.nil? && snapshot == baseline, "失敗時点の全体トーク #{partial} 件")

    # 5. ロック待ちの時間切れ → 再実行
    fresh_db!
    blocker = hold_lock("SELECT * FROM communities LIMIT 1")
    first, elapsed = try_migrate
    lock_ok = lock_timeout?(first) && elapsed.between?(4, 10) && applied.empty? && session_timeouts == session_before
    blocker.query("ROLLBACK")
    rerun, = try_migrate
    check.call("ロック待ち: communities を読むトランザクションが残る → 1本目が約5秒で失敗、解消後の再実行で一致", lock_ok && rerun.nil? && snapshot == baseline, format("%.1f秒", elapsed))

    fresh_db!
    blocker = hold_lock("SELECT * FROM project_chats LIMIT 1")
    first, elapsed = try_migrate
    lock_ok = lock_timeout?(first) && applied.empty?
    blocker.query("ROLLBACK")
    rerun, = try_migrate
    check.call("ロック待ち: 外部キーでつながる project_chats のトランザクションでも projects の ALTER が待つ → 失敗、再実行で一致", lock_ok && rerun.nil? && snapshot == baseline, format("%.1f秒", elapsed))

    fresh_db!
    blocker = nil
    Hooks.before_chats_column = -> { blocker = hold_lock("SELECT * FROM project_chats LIMIT 1") }
    first, = try_migrate
    Hooks.before_chats_column = nil
    lock_ok = lock_timeout?(first) && applied == VERSIONS.first(2) && connection.table_exists?(:project_threads)
    blocker.query("ROLLBACK")
    rerun, = try_migrate
    check.call("ロック待ち: 3本目の途中(project_threads 作成後)で失敗、再実行で一致", lock_ok && rerun.nil? && snapshot == baseline)

    fresh_db!
    Hooks.after_chats_fk = -> { blocker = hold_lock("SELECT id FROM project_chats WHERE id = 3 FOR UPDATE") }
    first, elapsed = try_migrate
    Hooks.after_chats_fk = nil
    lock_ok = lock_timeout?(first) && elapsed.between?(9, 20) && applied == VERSIONS.first(2)
    blocker.query("ROLLBACK")
    rerun, = try_migrate
    check.call("ロック待ち: 既存チャットの行ロック → 紐づけ UPDATE が約10秒で失敗、再実行で一致", lock_ok && rerun.nil? && snapshot == baseline, format("%.1f秒", elapsed))

    check.call("サーバー全体の設定(GLOBAL lock_wait_timeout / innodb_lock_wait_timeout)は不変", global_timeouts == globals_before, globals_before.inspect)

    puts(results.all? ? "ALL OK (#{results.size})" : "NG #{results.count(false)} / #{results.size}")
    results.all?
  end

  def guard!
    abort "CONFIRM_DISPOSABLE=yes を指定してください(使い捨ての MySQL にだけ使う)" unless ENV["CONFIRM_DISPOSABLE"] == "yes"
    abort "production 環境では実行しない" if Rails.env.production?
    host = ENV["CHECK_MYSQL_HOST"].to_s
    abort "CHECK_MYSQL_HOST を指定してください" if host.empty?
    abort "RDS のエンドポイントには実行しない" if host.include?("rds.amazonaws.com")
    abort "アプリの DB_HOST と同じホストには実行しない" if host == ENV["DB_HOST"].to_s
    existing = server.select_values("SHOW DATABASES").map(&:to_s) & [DB, REF_DB]
    abort "#{existing.join(', ')} が既にあります。前回の残りなら中身を確認してから削除してください" if existing.any?
    version = server.select_value("SELECT VERSION()").to_s
    abort "MySQL #{version} です(8.4 で検証する。手順の確認だけなら ALLOW_NON_84=1)" unless version.start_with?("8.4.") || ENV["ALLOW_NON_84"] == "1"
  end

  def connection_config(database = nil)
    {
      adapter: "mysql2", encoding: "utf8mb4", collation: "utf8mb4_general_ci",
      host: ENV["CHECK_MYSQL_HOST"], port: ENV.fetch("CHECK_MYSQL_PORT", 3306).to_i,
      username: ENV.fetch("CHECK_MYSQL_USER", "root"), password: ENV["CHECK_MYSQL_PASSWORD"],
      database: database
    }.compact
  end

  def server
    @server ||= begin
      ActiveRecord::Base.establish_connection(connection_config)
      ActiveRecord::Base.connection
    end
  end

  def connection
    ActiveRecord::Base.connection
  end

  def use_database(name)
    @server = nil
    ActiveRecord::Base.establish_connection(connection_config(name))
    connection.singleton_class.prepend(Hooks) unless connection.singleton_class.include?(Hooks)
  end

  def base_schema
    @base_schema ||= begin
      out, status = Open3.capture2("git", "-C", Rails.root.to_s, "show", "#{BASE_COMMIT}:db/schema.rb")
      abort "git show #{BASE_COMMIT}:db/schema.rb に失敗しました" unless status.success?
      out
    end
  end

  # 本番と同じ main 時点のスキーマに、旧データ(全体トーク無しのプロジェクト・スレッド未指定のチャット)を入れる。
  def fresh_db!
    connection.execute("DROP DATABASE IF EXISTS #{DB}")
    connection.execute("CREATE DATABASE #{DB} CHARACTER SET utf8mb4")
    use_database(DB)
    ActiveRecord::Migration.suppress_messages { eval(base_schema, TOPLEVEL_BINDING) }
    c = connection
    c.execute("SET FOREIGN_KEY_CHECKS=0")
    now = "'2026-01-01 00:00:00'"
    c.execute("INSERT INTO domains (id, name, created_at, updated_at) VALUES (1, 'business', #{now}, #{now})")
    c.execute("INSERT INTO communities (id, domain_id, name, created_at, updated_at) VALUES (1, 1, 'c', #{now}, #{now})")
    [1, 2, 3].each { |id| c.execute("INSERT INTO customers (id, email, joined_on, created_at, updated_at) VALUES (#{id}, 'u#{id}@example.com', '2026-01-01', #{now}, #{now})") }
    [1, 2, 3].each { |id| c.execute("INSERT INTO projects (id, community_id, customer_id, title, created_at, updated_at) VALUES (#{id}, 1, #{id}, 'p#{id}', #{now}, #{now})") }
    [[1, 1], [2, 1], [3, 2], [4, 2], [5, 2]].each do |id, project_id|
      c.execute("INSERT INTO project_chats (id, project_id, customer_id, body, created_at, updated_at) VALUES (#{id}, #{project_id}, 1, 'b', '2026-02-0#{id} 00:00:00', #{now})")
    end
    c.execute("SET FOREIGN_KEY_CHECKS=1")
    abort "起点のスキーマに対象のマイグレーションが含まれています" if applied.any?
    Hooks.seen = nil
  end

  def reference_schema
    use_database(REF_DB)
    ActiveRecord::Migration.suppress_messages { load Rails.root.join("db/schema.rb").to_s }
    dump = dump_schema
    use_database(DB)
    dump
  end

  def load_migration_classes
    ActiveRecord::MigrationContext.new(MIGRATIONS, ActiveRecord::SchemaMigration).migrations.each { |m| require File.expand_path(m.filename) }
  end

  def try_migrate
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ActiveRecord::Migration.suppress_messages { ActiveRecord::MigrationContext.new(MIGRATIONS, ActiveRecord::SchemaMigration).migrate }
    [nil, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started]
  rescue StandardError => e
    [e.cause.is_a?(InjectedFailure) ? e.cause : e, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started]
  end

  def lock_timeout?(error)
    error.is_a?(ActiveRecord::LockWaitTimeout) || error&.cause.is_a?(ActiveRecord::LockWaitTimeout)
  end

  def describe(error)
    "#{error.class}: #{error.message.lines.first.to_s.strip[0, 160]}"
  end

  def hold_lock(sql)
    client = Mysql2::Client.new(**connection_config(DB).slice(:host, :port, :username, :password, :database))
    client.query("BEGIN")
    client.query(sql)
    client
  end

  def applied
    connection.select_values("SELECT version FROM schema_migrations WHERE version LIKE '20261027%' ORDER BY version")
  end

  def session_timeouts
    connection.select_rows("SELECT @@SESSION.lock_wait_timeout, @@SESSION.innodb_lock_wait_timeout").first.map(&:to_i)
  end

  def global_timeouts
    connection.select_rows("SELECT @@GLOBAL.lock_wait_timeout, @@GLOBAL.innodb_lock_wait_timeout").first.map(&:to_i)
  end

  def dump_schema
    io = StringIO.new
    ActiveRecord::SchemaDumper.dump(connection, io)
    io.string.sub(/version: [\d_]+/, "")
  end

  def snapshot
    c = connection
    {
      schema: dump_schema,
      pending: ActiveRecord::MigrationContext.new(MIGRATIONS, ActiveRecord::SchemaMigration).needs_migration?,
      threads: c.select_rows("SELECT project_id, title, general, last_posted_at FROM project_threads ORDER BY project_id, id"),
      chats: c.select_rows("SELECT id, project_thread_id IS NOT NULL FROM project_chats ORDER BY id"),
      modes: c.select_rows("SELECT 'c', id, join_approval_mode FROM communities UNION ALL SELECT 'p', id, join_approval_mode FROM projects ORDER BY 1, 2")
    }
  end

  # 制約の確認は1つずつ巻き戻し、後続の比較に影響させない。
  def constraint_checks
    now = "NOW()"
    rejected = lambda do |error_class, sql_list|
      connection.transaction(requires_new: true) do
        sql_list[0..-2].each { |sql| connection.execute(sql) }
        connection.execute(sql_list.last)
        raise ActiveRecord::Rollback
      end
      false
    rescue error_class
      true
    end
    accepted = lambda do |sql_list, &verify|
      ok = false
      connection.transaction(requires_new: true) do
        sql_list.each { |sql| connection.execute(sql) }
        ok = verify ? verify.call : true
        raise ActiveRecord::Rollback
      end
      ok
    end
    thread = ->(general) { "INSERT INTO project_threads (project_id, title, general, last_posted_at, created_at, updated_at) VALUES (1, 't', #{general}, #{now}, #{now}, #{now})" }
    request = "INSERT INTO project_join_requests (project_id, customer_id, created_at, updated_at) VALUES (1, 2, #{now}, #{now})"
    suspension = ->(table, target) { "INSERT INTO #{table} (#{target}_id, customer_id, created_at, updated_at) VALUES (1, 2, #{now}, #{now})" }

    {
      "全体トーク(general=TRUE)は1プロジェクトに2つ作れない" => rejected.call(ActiveRecord::RecordNotUnique, [thread.call("TRUE")]),
      "通常のスレッド(general=NULL)は同じプロジェクトにいくつでも作れる" => accepted.call([thread.call("NULL"), thread.call("NULL")]),
      "プロジェクト参加申請は同じ人・同じプロジェクトで重複できない" => rejected.call(ActiveRecord::RecordNotUnique, [request, request]),
      "コミュニティのアクセス停止は重複できない" => rejected.call(ActiveRecord::RecordNotUnique, [suspension.call(:community_access_suspensions, :community)] * 2),
      "プロジェクトのアクセス停止は重複できない" => rejected.call(ActiveRecord::RecordNotUnique, [suspension.call(:project_access_suspensions, :project)] * 2),
      "存在しないプロジェクトへの参加申請は外部キーで拒否" => rejected.call(ActiveRecord::InvalidForeignKey, ["INSERT INTO project_join_requests (project_id, customer_id, created_at, updated_at) VALUES (999, 2, #{now}, #{now})"]),
      "存在しないスレッドへのチャットは外部キーで拒否" => rejected.call(ActiveRecord::InvalidForeignKey, ["INSERT INTO project_chats (project_id, customer_id, body, project_thread_id, created_at, updated_at) VALUES (1, 1, 'x', 999, #{now}, #{now})"]),
      "全体トークがあるプロジェクトは削除できない(外部キー)" => rejected.call(ActiveRecord::InvalidForeignKey, ["DELETE FROM projects WHERE id = 3"]),
      "作成者なし(customer_id NULL)のプロジェクト・スレッドを保存できる" => accepted.call(["INSERT INTO projects (community_id, customer_id, title, created_at, updated_at) VALUES (1, NULL, 'x', #{now}, #{now})", thread.call("NULL")]),
      "旧コード相当の書き込み(スレッド未指定のチャット)を保存でき、新規プロジェクトの既定は手動承認(0)" => accepted.call([
        "INSERT INTO project_chats (project_id, customer_id, body, created_at, updated_at) VALUES (1, 1, 'old', #{now}, #{now})",
        "INSERT INTO projects (community_id, customer_id, title, created_at, updated_at) VALUES (1, 1, 'old', #{now}, #{now})",
        "INSERT INTO communities (domain_id, name, created_at, updated_at) VALUES (1, 'old', #{now}, #{now})"
      ]) do
        connection.select_value("SELECT project_thread_id FROM project_chats WHERE body = 'old'").nil? &&
          connection.select_value("SELECT join_approval_mode FROM projects WHERE title = 'old'").to_i.zero? &&
          connection.select_value("SELECT join_approval_mode FROM communities WHERE name = 'old'").to_i.zero?
      end
    }
  end

  def cleanup!
    # guard! で止まった場合(既存の同名 DB がある等)は何も消さない。
    return unless @created

    use_database(nil)
    [DB, REF_DB].each { |name| connection.execute("DROP DATABASE IF EXISTS #{name}") }
  rescue StandardError => e
    warn "後片付けに失敗しました(#{e.class})。#{DB} / #{REF_DB} を手動で削除してください"
  end
end

ActiveRecord::Base.logger = nil
exit(BusinessMigrationMysqlCheck.run ? 0 : 1)
