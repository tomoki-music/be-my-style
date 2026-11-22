# Business スレッド・参加承認のマイグレーション(20261027000000〜000300)と、プロジェクトのテーマ追加(20261030000000)、
# スレッド投稿通知の投稿ID(20261101000000)、イベントの開催コミュニティ(20261107000000)を、
# 使い捨ての MySQL で検証する。
# 本番・開発の DB には使わない。指定したサーバーに専用の DB を2つ作り、終了時に削除する。
#
#   CHECK_MYSQL_HOST=127.0.0.1 CHECK_MYSQL_PORT=3307 CHECK_MYSQL_USER=root CONFIRM_DISPOSABLE=yes \
#     RAILS_ENV=test bundle exec rails runner script/business_migration_mysql_check.rb
#
# 確認内容: 通常移行(本番と同じ main 時点のスキーマ + 旧データから) / db/schema.rb とのスキーマ一致 /
# 一意制約・外部キー・NULL 許容 / 途中失敗(8か所)後の再実行 / ロック待ちの時間切れと再実行 / サーバー全体の設定が不変 /
# 通知の DDL の方式(ALGORITHM / LOCK)と既存通知の不変 / 同じ投稿の通知処理の同時実行 /
# 移行前のイベントの主催コミュニティの引き継ぎ。
# MySQL 8.4 以外では止まる(ALLOW_NON_84=1 で手順そのものの確認用に実行できる)。
require "open3"
require "stringio"

module BusinessMigrationMysqlCheck
  # 本番に適用済みのスキーマ(schema version 20261018000000)を持つ main のコミット。
  BASE_COMMIT = "8acf938f".freeze
  DB = "bms_migration_check_tmp".freeze
  REF_DB = "bms_migration_check_ref_tmp".freeze
  MIGRATIONS = Rails.root.join("db/migrate").to_s
  VERSIONS = %w[20261027000000 20261027000100 20261027000200 20261027000300 20261030000000 20261101000000 20261107000000].freeze
  # テーマ追加の直前(スレッド・参加承認の4本まで)。本番はこの状態から 5本目だけを適用する。
  BEFORE_THEME = "20261027000300".freeze
  # 通知の投稿ID追加の直前(本番適用済みの5本まで)。本番はこの状態から 6本目だけを適用する。
  BEFORE_NOTIFICATION = "20261030000000".freeze
  NOTIFICATION_INDEX = "index_notifications_on_project_chat_id_and_visited_id".freeze
  # 開催コミュニティの直前(本番適用済みの6本まで)。本番はこの状態から 7本目だけを適用する。
  BEFORE_EVENT_COMMUNITIES = "20261101000000".freeze
  # 移行前のイベント。[id, 主催コミュニティの id]
  LEGACY_EVENTS = [[1, 1], [2, 1], [3, 2]].freeze

  class InjectedFailure < StandardError; end

  module Hooks
    class << self
      attr_accessor :fail_at, :seen, :before_chats_column, :after_chats_fk, :notification_ddl
    end

    # 6本目は方式(ALGORITHM / LOCK)を明示するため、DDL を execute で直接実行する。
    def execute(sql, name = nil)
      if sql.to_s.match?(/\AALTER TABLE notifications /)
        Hooks.seen ||= select_rows("SELECT @@SESSION.lock_wait_timeout, @@SESSION.innodb_lock_wait_timeout").first.map(&:to_i)
        (Hooks.notification_ddl ||= []) << sql
        raise InjectedFailure if Hooks.fail_at.is_a?(Array) && Hooks.fail_at.first == :execute && sql.match?(Hooks.fail_at.last)
      end
      super
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
    "5本目: 4本の適用後、projects.theme の追加で失敗" => [:add_column, :projects, :theme],
    "6本目: notifications.project_chat_id の追加後、一意索引で失敗" => [:execute, /ADD UNIQUE INDEX/],
    "7本目: event_communities の作成後、一意索引で失敗" => [:add_index, :event_communities, %i[event_id community_id]],
    "7本目: 索引の作成後、外部キー(events)で失敗" => [:add_foreign_key, :event_communities, :events],
    "7本目: 外部キー(events)の作成後、外部キー(communities)で失敗" => [:add_foreign_key, :event_communities, :communities],
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
    row_versions_before = notification_row_versions
    Hooks.notification_ddl = nil
    error, = try_migrate
    baseline = snapshot
    check.call("通常移行: #{VERSIONS.size}本とも成功", error.nil? && applied == VERSIONS, error && describe(error))
    check.call("通常移行: 実行中だけロック待ち上限 5秒/10秒、終了後は元の値", Hooks.seen == [5, 10] && session_timeouts == session_before, "#{Hooks.seen.inspect} 後=#{session_timeouts.inspect}")
    check.call("通常移行: 全体トークが各プロジェクトに1つ・既存チャットは全件紐づけ", baseline[:threads].map(&:first) == [1, 2, 3] && baseline[:chats].all? { |_, linked| linked == 1 })
    check.call("通常移行: 参加方式 既存コミュニティ=手動(0)・既存プロジェクト=自動(1)", baseline[:modes] == [["c", 1, 0], ["c", 2, 0], ["p", 1, 1], ["p", 2, 1], ["p", 3, 1]], baseline[:modes].inspect)
    check.call("通常移行: テーマは varchar(100)・NULL 許容で、既存プロジェクトは未設定(NULL)・目標と締切の値はそのまま",
               theme_column == ["varchar(100)", "YES", nil] && baseline[:legacy] == LEGACY_PROJECT_VALUES,
               "#{theme_column.inspect} #{baseline[:legacy].inspect}")

    check.call("通常移行: 通知の投稿IDは bigint・NULL 許容で、既存の通知は全列そのまま・投稿ID未設定(NULL)",
               notification_column == ["bigint", "YES", nil] && baseline[:notifications] == LEGACY_NOTIFICATIONS &&
                 connection.select_values("SELECT project_chat_id FROM notifications").compact.empty?,
               "#{notification_column.inspect} #{baseline[:notifications].inspect}")
    check.call("通常移行: 移行前のイベントの主催コミュニティを開催コミュニティへ1件ずつ引き継ぐ",
               baseline[:event_communities] == LEGACY_EVENTS, baseline[:event_communities].inspect)
    check.call("通常移行: events の主催コミュニティ・更新日時は変わらない",
               baseline[:events] == LEGACY_EVENTS.map { |id, community_id| [id, community_id, "2026-01-01 00:00:00"] }, baseline[:events].inspect)
    event_rows = LEGACY_EVENTS.map { |id, community_id| event = Event.find(id); [event.id, event.community_id, event.all_hosting_community_ids] }
    check.call("通常移行: アプリのコードからも移行前のイベントの主催を開催コミュニティとして読める",
               event_rows == LEGACY_EVENTS.map { |id, community_id| [id, community_id, [community_id]] } &&
                 Event.hosted_by(1).order(:id).pluck(:id) == [1, 2] && Event.hosted_by(2).pluck(:id) == [3],
               event_rows.inspect)
    ddl = Array(Hooks.notification_ddl)
    check.call("通常移行: 6本目は列追加 ALGORITHM=INSTANT・一意索引 ALGORITHM=INPLACE, LOCK=NONE を指定し、サーバーが受け付けた",
               ddl.size == 2 && ddl[0].include?("ADD COLUMN project_chat_id bigint NULL, ALGORITHM=INSTANT") &&
                 ddl[1].include?("ADD UNIQUE INDEX #{NOTIFICATION_INDEX} (project_chat_id, visited_id), ALGORITHM=INPLACE, LOCK=NONE"),
               ddl.map { |sql| sql[/ALGORITHM=.*/] }.inspect)
    row_versions_after = notification_row_versions
    check.call("通常移行: 列追加は表を作り直していない(INSTANT で行バージョンが1つ増える)",
               row_versions_after == row_versions_before + 1, "TOTAL_ROW_VERSIONS #{row_versions_before} → #{row_versions_after}")

    # 2. スキーマ一致(同じサーバーで db/schema.rb を読み込んだ DB と比べる)
    check.call("スキーマ: マイグレーション結果が db/schema.rb と一致", baseline[:schema] == reference_schema, "差分は #{DB}.schema / #{REF_DB}.schema を SchemaDumper で比較")

    # 3. 制約
    constraint_checks.each { |name, ok| check.call("制約: #{name}", ok) }

    # 同じ投稿の通知処理を同時に実行する(アプリのコードを、別々の接続から同時に動かす)
    concurrent_notify_checks.each { |name, ok, detail| check.call("同時実行: #{name}", ok, detail) }

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
    # 5本目(テーマ追加)は、本番と同じく 4本の適用後に単独で実行し、projects を読むトランザクションが残る場合を見る。
    fresh_db!
    migrate_to(BEFORE_THEME)
    Hooks.seen = nil
    blocker = hold_lock("SELECT * FROM projects LIMIT 1")
    first, elapsed = try_migrate
    lock_ok = lock_timeout?(first) && elapsed.between?(4, 10) && applied == VERSIONS.first(4) &&
      !connection.column_exists?(:projects, :theme) && Hooks.seen == [5, 10] && session_timeouts == session_before
    blocker.query("ROLLBACK")
    rerun, = try_migrate
    check.call("ロック待ち: 5本目 projects を読むトランザクションが残る → 約5秒で失敗(上限 5秒/10秒)、解消後の再実行で一致", lock_ok && rerun.nil? && snapshot == baseline, format("%.1f秒", elapsed))

    # 6本目(通知の投稿ID)も、本番と同じく 5本の適用後に単独で実行する。
    fresh_db!
    migrate_to(BEFORE_NOTIFICATION)
    Hooks.seen = nil
    blocker = hold_lock("SELECT * FROM notifications LIMIT 1")
    first, elapsed = try_migrate
    lock_ok = lock_timeout?(first) && elapsed.between?(4, 10) && applied == VERSIONS.first(5) &&
      !connection.column_exists?(:notifications, :project_chat_id) && Hooks.seen == [5, 10] && session_timeouts == session_before
    blocker.query("ROLLBACK")
    rerun, = try_migrate
    check.call("ロック待ち: 6本目 notifications を読むトランザクションが残る → 約5秒で失敗(上限 5秒/10秒)、解消後の再実行で一致", lock_ok && rerun.nil? && snapshot == baseline, format("%.1f秒", elapsed))

    # 7本目(開催コミュニティ)も、本番と同じく 6本の適用後に単独で実行する。外部キーの作成は参照先の
    # events への書き込み中のトランザクションを待つ。
    fresh_db!
    migrate_to(BEFORE_EVENT_COMMUNITIES)
    blocker = hold_lock("UPDATE events SET place = place WHERE id = 1")
    first, elapsed = try_migrate
    lock_ok = lock_timeout?(first) && applied == VERSIONS.first(6) && session_timeouts == session_before
    blocker.query("ROLLBACK")
    rerun, = try_migrate
    check.call("ロック待ち: 7本目 events を更新中のトランザクションが残る → 時間切れで失敗、解消後の再実行で一致", lock_ok && rerun.nil? && snapshot == baseline, format("%.1f秒", elapsed))

    # 列・索引の追加までは終わったが schema_migrations に記録される前に止まった場合(手動適用も同じ状態)。
    fresh_db!
    migrate_to(BEFORE_NOTIFICATION)
    connection.execute("ALTER TABLE notifications ADD COLUMN project_chat_id bigint NULL, ALGORITHM=INSTANT")
    connection.execute("ALTER TABLE notifications ADD UNIQUE INDEX #{NOTIFICATION_INDEX} (project_chat_id, visited_id), ALGORITHM=INPLACE, LOCK=NONE")
    Hooks.notification_ddl = nil
    rerun, = try_migrate
    check.call("途中適用済み(列・索引あり、未記録)からの 6本目の再実行は DDL を実行せずに一致", rerun.nil? && Hooks.notification_ddl.nil? && snapshot == baseline, rerun && describe(rerun))

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
      database: database, pool: CONCURRENT_WORKERS + 2
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
    c.execute("INSERT INTO communities (id, domain_id, name, created_at, updated_at) VALUES (1, 1, 'c', #{now}, #{now}), (2, 1, 'c2', #{now}, #{now})")
    [1, 2, 3].each { |id| c.execute("INSERT INTO customers (id, email, joined_on, created_at, updated_at) VALUES (#{id}, 'u#{id}@example.com', '2026-01-01', #{now}, #{now})") }
    [1, 2, 3].each { |id| c.execute("INSERT INTO projects (id, community_id, customer_id, title, created_at, updated_at) VALUES (#{id}, 1, #{id}, 'p#{id}', #{now}, #{now})") }
    c.execute("UPDATE projects SET goal = '既存の目標', deadline = '2026-03-01 00:00:00' WHERE id = 1")
    [[1, 1], [2, 1], [3, 2], [4, 2], [5, 2]].each do |id, project_id|
      c.execute("INSERT INTO project_chats (id, project_id, customer_id, body, created_at, updated_at) VALUES (#{id}, #{project_id}, 1, 'b', '2026-02-0#{id} 00:00:00', #{now})")
    end
    LEGACY_NOTIFICATION_ROWS.each do |id, visited_id, action, project_id|
      c.execute("INSERT INTO notifications (id, visitor_id, visited_id, action, project_id, created_at, updated_at) VALUES (#{id}, 1, #{visited_id}, '#{action}', #{project_id || 'NULL'}, #{now}, #{now})")
    end
    LEGACY_EVENTS.each do |id, community_id|
      c.execute("INSERT INTO events (id, customer_id, community_id, event_name, event_start_time, event_end_time, event_entry_deadline, entrance_fee, place, address, created_at, updated_at) VALUES (#{id}, 1, #{community_id}, 'e#{id}', #{now}, #{now}, #{now}, 0, 'p', 'a', #{now}, #{now})")
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

  # 取りやめた目標・締切の既存データ(テーマへ転記しない)。[id, goal, deadline, theme]
  LEGACY_PROJECT_VALUES = [[1, "既存の目標", "2026-03-01 00:00:00", nil], [2, nil, nil, nil], [3, nil, nil, nil]].freeze

  # 既存の通知(同じ宛先・同じプロジェクトの project_message が複数ある)。[id, visited_id, action, project_id]
  LEGACY_NOTIFICATION_ROWS = [[1, 2, "project_message", 1], [2, 2, "project_message", 1], [3, 3, "follow", nil]].freeze
  # 移行後の比較用(移行前の全列)。[id, visitor_id, visited_id, action, checked, project_id, created_at, updated_at]
  LEGACY_NOTIFICATIONS = LEGACY_NOTIFICATION_ROWS.map do |id, visited_id, action, project_id|
    [id, 1, visited_id, action, 0, project_id, "2026-01-01 00:00:00", "2026-01-01 00:00:00"]
  end.freeze
  CONCURRENT_WORKERS = 8

  # INSTANT の列追加だけが増やす行バージョン数(表を作り直すと 0 に戻る)。
  def notification_row_versions
    connection.select_value(<<~SQL).to_i
      SELECT TOTAL_ROW_VERSIONS FROM information_schema.INNODB_TABLES WHERE NAME = CONCAT(DATABASE(), '/notifications')
    SQL
  end

  # 移行後の DB に参加者を入れ、同じ投稿の NotifyPost を別々の接続から同時に実行する。
  # 会員 1 = プロジェクト1の作成者で投稿者(全体トークの既存チャット id=1)。4〜9 が参加者で、偶数だけメール受信を許可。
  def concurrent_notify_checks
    c = connection
    recipients = (4..9).to_a
    mail_on = recipients.select(&:even?)
    recipients.each do |id|
      c.execute("INSERT INTO customers (id, email, joined_on, confirm_mail, created_at, updated_at) VALUES (#{id}, 'u#{id}@example.com', '2026-01-01', #{mail_on.include?(id) ? 1 : 0}, NOW(), NOW())")
      c.execute("INSERT INTO project_members (project_id, customer_id, created_at, updated_at) VALUES (1, #{id}, NOW(), NOW())")
    end
    ([1] + recipients).each { |id| c.execute("INSERT INTO community_customers (community_id, customer_id, created_at, updated_at) VALUES (1, #{id}, NOW(), NOW())") }

    Rails.application.eager_load!
    adapter = ActiveJob::Base.queue_adapter
    adapter.enqueued_jobs.clear
    gate = Queue.new
    workers = Array.new(CONCURRENT_WORKERS) do
      Thread.new do
        gate.pop
        ActiveRecord::Base.connection_pool.with_connection { Business::ProjectThreads::NotifyPost.call(ProjectChat.find(1)).map(&:id) }
      end
    end
    CONCURRENT_WORKERS.times { gate << true }
    per_worker = workers.map(&:value)
    returned = per_worker.flatten

    counts = c.select_rows("SELECT visited_id, COUNT(*) FROM notifications WHERE project_chat_id = 1 GROUP BY visited_id ORDER BY visited_id")
    mail_ids = adapter.enqueued_jobs.select { |job| job[:args]&.first == "BusinessProjectChatMailer" }
                      .map { |job| job[:args].last["params"]["notification_id"] }
    mail_targets = c.select_values("SELECT visited_id FROM notifications WHERE id IN (#{(mail_ids + [0]).join(',')}) ORDER BY visited_id")
    rerun = Business::ProjectThreads::NotifyPost.call(ProjectChat.find(1))
    total_after_rerun = c.select_value("SELECT COUNT(*) FROM notifications WHERE project_chat_id = 1").to_i

    [
      ["#{CONCURRENT_WORKERS}本同時でも宛先ごとに通知は1件(投稿者・非参加者には無し)", counts == recipients.map { |id| [id, 1] }, counts.inspect],
      ["新しく通知した宛先は全体で1回ずつ(どの実行が作ったかは問わない)", returned.sort == recipients, "実行ごとの作成数 #{per_worker.map(&:size).inspect}"],
      ["メールの登録は受信許可の宛先に1件ずつ", mail_ids.uniq.size == mail_ids.size && mail_targets == mail_on, "#{mail_ids.size}件 #{mail_targets.inspect}"],
      ["同時実行の後の再実行では何も増えない", rerun.empty? && total_after_rerun == recipients.size, "#{total_after_rerun}件"]
    ]
  ensure
    adapter&.enqueued_jobs&.clear
  end

  def notification_column
    connection.select_rows(<<~SQL).first
      SELECT DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'notifications' AND COLUMN_NAME = 'project_chat_id'
    SQL
  end

  def theme_column
    connection.select_rows(<<~SQL).first
      SELECT COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects' AND COLUMN_NAME = 'theme'
    SQL
  end

  def migrate_to(version)
    ActiveRecord::Migration.suppress_messages { ActiveRecord::MigrationContext.new(MIGRATIONS, ActiveRecord::SchemaMigration).up(version.to_i) }
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
    connection.select_values("SELECT version FROM schema_migrations WHERE version IN (#{VERSIONS.map { |v| "'#{v}'" }.join(', ')}) ORDER BY version")
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
      modes: c.select_rows("SELECT 'c', id, join_approval_mode FROM communities UNION ALL SELECT 'p', id, join_approval_mode FROM projects ORDER BY 1, 2"),
      events: c.select_rows("SELECT id, community_id, DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s') FROM events ORDER BY id"),
      event_communities: c.table_exists?(:event_communities) ? c.select_rows("SELECT event_id, community_id FROM event_communities ORDER BY event_id, community_id") : nil,
      legacy: c.column_exists?(:projects, :theme) ? c.select_rows("SELECT id, goal, DATE_FORMAT(deadline, '%Y-%m-%d %H:%i:%s'), theme FROM projects ORDER BY id") : nil,
      notifications: c.select_rows(<<~SQL)
        SELECT id, visitor_id, visited_id, action, checked, project_id,
               DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s'), DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s')
        FROM notifications WHERE id <= 3 ORDER BY id
      SQL
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
    notification = ->(chat_id, visited_id) { "INSERT INTO notifications (visitor_id, visited_id, action, project_chat_id, created_at, updated_at) VALUES (1, #{visited_id}, 'project_message', #{chat_id}, #{now}, #{now})" }
    event_community = ->(event_id, community_id) { "INSERT INTO event_communities (event_id, community_id, created_at, updated_at) VALUES (#{event_id}, #{community_id}, #{now}, #{now})" }
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
      "スレッド投稿の通知は同じ投稿・同じ宛先で重複できない" => rejected.call(ActiveRecord::RecordNotUnique, [notification.call(1, 2)] * 2),
      "同じ投稿の別の宛先・投稿IDの無い通知は重ねて保存できる" => accepted.call([notification.call(1, 2), notification.call(1, 3), notification.call("NULL", 2), notification.call("NULL", 2)]),
      "開催コミュニティは同じイベント・同じコミュニティで重複できない" => rejected.call(ActiveRecord::RecordNotUnique, [event_community.call(1, 1)]),
      "開催コミュニティは存在しないイベント・コミュニティを外部キーで拒否" =>
        rejected.call(ActiveRecord::InvalidForeignKey, [event_community.call(999, 1)]) &&
        rejected.call(ActiveRecord::InvalidForeignKey, [event_community.call(1, 999)]),
      "イベントを直接削除すると開催コミュニティの行も消える" => accepted.call(["DELETE FROM events WHERE id = 3"]) { connection.select_value("SELECT COUNT(*) FROM event_communities WHERE event_id = 3").to_i.zero? },
      "テーマは100文字まで保存でき、101文字は拒否" =>
        accepted.call(["UPDATE projects SET theme = REPEAT('あ', 100) WHERE id = 1"]) { connection.select_value("SELECT CHAR_LENGTH(theme) FROM projects WHERE id = 1").to_i == 100 } &&
        rejected.call(ActiveRecord::ValueTooLong, ["UPDATE projects SET theme = REPEAT('あ', 101) WHERE id = 1"]),
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
