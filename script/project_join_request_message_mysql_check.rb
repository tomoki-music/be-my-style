# プロジェクト参加申請のメッセージ列(20261110200000)を、使い捨ての MySQL で検証する。
# 本番・開発の DB には使わない。指定したサーバーに専用の DB を2つ作り、終了時に削除する。
#
#   CHECK_MYSQL_HOST=127.0.0.1 CHECK_MYSQL_PORT=3307 CHECK_MYSQL_USER=root CONFIRM_DISPOSABLE=yes \
#     RAILS_ENV=test bundle exec rails runner script/project_join_request_message_mysql_check.rb
#
# 確認内容: 本番適用済みのスキーマ(BASE_COMMIT)+既存の申請データから適用 / 列の型・NULL 許容 /
# 既存の申請は全列そのまま・メッセージなし(NULL) / アプリのコードからもメッセージなしとして読める /
# 表を作り直さない(INSTANT) / db/schema.rb とのスキーマ一致 / 一意制約の維持 / 再実行・戻し・再適用。
# MySQL 8.4 以外では止まる(ALLOW_NON_84=1 で手順そのものの確認用に実行できる)。
require "open3"
require "stringio"

module ProjectJoinRequestMessageMysqlCheck
  # 本番に適用済みのスキーマ(schema version 20261110100000)を持つ main のコミット(PR #235 のマージ)。
  BASE_COMMIT = "2cbf46c5".freeze
  DB = "bms_join_message_check_tmp".freeze
  REF_DB = "bms_join_message_check_ref_tmp".freeze
  MIGRATIONS = Rails.root.join("db/migrate").to_s
  VERSION = "20261110200000".freeze
  # 既存の申請。[id, project_id, customer_id, created_at]
  LEGACY_REQUESTS = [[1, 1, 2, "2026-11-01 10:00:00"], [2, 1, 3, "2026-11-02 11:00:00"], [3, 2, 2, "2026-11-03 12:00:00"]].freeze

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

    @created = true
    server.execute("CREATE DATABASE #{DB} CHARACTER SET utf8mb4")
    server.execute("CREATE DATABASE #{REF_DB} CHARACTER SET utf8mb4")
    puts "MySQL #{connection.select_value('SELECT VERSION()')} / 起点 #{BASE_COMMIT} / 対象 #{VERSION}"

    fresh_db!
    before = legacy_rows
    versions_before = row_versions
    check.call("起点: 本番と同じスキーマに message 列は無く、対象のマイグレーションだけが未適用", !connection.column_exists?(:project_join_requests, :message) && pending_versions == [VERSION], pending_versions.inspect)

    migrate_up
    column = message_column
    check.call("適用: 成功し、未適用のマイグレーションが残らない", pending_versions.empty?)
    check.call("適用: message は text・NULL 許容・既定値なし", column == ["text", "YES", nil], column.inspect)
    check.call("適用: 表を作り直していない(INSTANT で行バージョンが1つ増える)", row_versions == versions_before + 1, "TOTAL_ROW_VERSIONS #{versions_before} → #{row_versions}")
    after = legacy_rows
    check.call("既存の申請: 件数・ID・申請先・申請者・日時はそのまま", after.map { |row| row.first(5) } == before, after.inspect)
    check.call("既存の申請: すべてメッセージなし(NULL)", after.all? { |row| row.last.nil? })

    ProjectJoinRequest.reset_column_information
    legacy = ProjectJoinRequest.order(:id).to_a
    check.call("アプリ: 既存の申請はメッセージなしとして読める(message.present? が偽)", legacy.size == 3 && legacy.none? { |r| r.message.present? })
    check.call("アプリ: 既存の申請も更新時の検証を通る", legacy.all?(&:valid?))

    app_checks(check)

    check.call("スキーマ: マイグレーション結果が db/schema.rb と一致", dump_schema == reference_schema)

    unique_ok = begin
      connection.transaction(requires_new: true) do
        connection.execute("INSERT INTO project_join_requests (project_id, customer_id, created_at, updated_at) VALUES (1, 2, NOW(), NOW())")
        raise ActiveRecord::Rollback
      end
      false
    rescue ActiveRecord::RecordNotUnique
      true
    end
    check.call("制約: 同じ人・同じプロジェクトの申請は引き続き重複できない", unique_ok)

    migrate_up
    check.call("再実行: もう一度 migrate しても何も起きない", pending_versions.empty? && message_column == ["text", "YES", nil])

    ActiveRecord::Migration.suppress_messages { context.down(BASE_VERSION) }
    rows_after_down = legacy_rows
    check.call("戻し: down で列だけ消え、既存の申請は残る", !connection.column_exists?(:project_join_requests, :message) && rows_after_down.map { |row| row.first(5) }.first(3) == before)

    # MySQL の DDL は巻き戻らないため、列の追加後・記録前に止まった状態を作ってから再実行する。
    connection.add_column(:project_join_requests, :message, :text)
    migrate_up
    check.call("途中失敗後: 列だけ先に追加され記録が無い状態からでも再実行できる", pending_versions.empty? && message_column == ["text", "YES", nil])

    puts(results.all? ? "結果: すべて OK" : "結果: NG あり")
    results.all?
  end

  BASE_VERSION = 20261110100000

  def app_checks(check)
    project = Project.find(1)
    customer = Customer.find(4)
    text = "興味があります🎸\n担当してみたいです"
    created = ProjectJoinRequest.create!(project: project, customer: customer, message: "  #{text}  ")
    check.call("アプリ: 新しい申請はメッセージを保存できる(絵文字・改行を含む)", created.reload.message == text, created.message.inspect)

    long = ProjectJoinRequest.new(project: Project.find(2), customer: customer, message: "あ" * 500)
    too_long = ProjectJoinRequest.new(project: Project.find(2), customer: customer, message: "あ" * 501)
    saved_500 = long.save
    check.call("アプリ: 500文字は保存でき、501文字は検証で止まる", saved_500 && long.reload.message.length == 500 && !too_long.valid?)

    blank = ProjectJoinRequest.create!(project: Project.find(3), customer: customer, message: " \n ")
    check.call("アプリ: 空白だけのメッセージは NULL で保存する", connection.select_value("SELECT message FROM project_join_requests WHERE id = #{blank.id}").nil?)

    [created, long, blank].each(&:destroy!)
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
      database: database, pool: 2
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
  end

  def context
    ActiveRecord::MigrationContext.new(MIGRATIONS, ActiveRecord::SchemaMigration)
  end

  def migrate_up
    ActiveRecord::Migration.suppress_messages { context.up(VERSION.to_i) }
  end

  def pending_versions
    context.migrations.map { |m| m.version.to_s } - connection.select_values("SELECT version FROM schema_migrations").map(&:to_s)
  end

  def base_schema
    out, status = Open3.capture2("git", "-C", Rails.root.to_s, "show", "#{BASE_COMMIT}:db/schema.rb")
    abort "git show #{BASE_COMMIT}:db/schema.rb に失敗しました" unless status.success?
    out
  end

  # 本番と同じ main 時点のスキーマに、既存の申請データ(メッセージ列が無い時代の行)を入れる。
  def fresh_db!
    use_database(DB)
    ActiveRecord::Migration.suppress_messages { eval(base_schema, TOPLEVEL_BINDING) }
    ActiveRecord::SchemaMigration.create_table
    context.migrations.each do |m|
      next if m.version >= VERSION.to_i

      connection.execute("INSERT IGNORE INTO schema_migrations (version) VALUES ('#{m.version}')")
    end
    c = connection
    now = "'2026-01-01 00:00:00'"
    c.execute("SET FOREIGN_KEY_CHECKS=0")
    c.execute("INSERT INTO domains (id, name, created_at, updated_at) VALUES (1, 'business', #{now}, #{now})")
    c.execute("INSERT INTO communities (id, domain_id, name, created_at, updated_at) VALUES (1, 1, 'c', #{now}, #{now})")
    [1, 2, 3, 4].each { |id| c.execute("INSERT INTO customers (id, email, joined_on, created_at, updated_at) VALUES (#{id}, 'u#{id}@example.com', '2026-01-01', #{now}, #{now})") }
    [1, 2, 3].each { |id| c.execute("INSERT INTO projects (id, community_id, customer_id, title, created_at, updated_at) VALUES (#{id}, 1, 1, 'p#{id}', #{now}, #{now})") }
    LEGACY_REQUESTS.each do |id, project_id, customer_id, at|
      c.execute("INSERT INTO project_join_requests (id, project_id, customer_id, created_at, updated_at) VALUES (#{id}, #{project_id}, #{customer_id}, '#{at}', '#{at}')")
    end
    c.execute("SET FOREIGN_KEY_CHECKS=1")
  end

  def legacy_rows
    columns = "id, project_id, customer_id, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s'), DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s')"
    columns += ", message" if connection.column_exists?(:project_join_requests, :message)
    connection.select_rows("SELECT #{columns} FROM project_join_requests WHERE id <= 3 ORDER BY id")
  end

  def message_column
    connection.select_rows(<<~SQL).first
      SELECT DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'project_join_requests' AND COLUMN_NAME = 'message'
    SQL
  end

  def row_versions
    connection.select_value(<<~SQL).to_i
      SELECT TOTAL_ROW_VERSIONS FROM information_schema.INNODB_TABLES WHERE NAME = CONCAT(DATABASE(), '/project_join_requests')
    SQL
  end

  def reference_schema
    use_database(REF_DB)
    ActiveRecord::Migration.suppress_messages { load Rails.root.join("db/schema.rb").to_s }
    dump = dump_schema
    use_database(DB)
    dump
  end

  def dump_schema
    io = StringIO.new
    ActiveRecord::SchemaDumper.dump(connection, io)
    io.string.sub(/version: [\d_]+/, "")
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
exit(ProjectJoinRequestMessageMysqlCheck.run ? 0 : 1)
