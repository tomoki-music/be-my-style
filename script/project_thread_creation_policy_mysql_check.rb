# プロジェクトの「スレッドを作成できる人」の列(20261110400000)を、使い捨ての MySQL で検証する。
# 本番・開発の DB には使わない。指定したサーバーに専用の DB を2つ作り、終了時に削除する。
#
#   CHECK_MYSQL_HOST=127.0.0.1 CHECK_MYSQL_PORT=3307 CHECK_MYSQL_USER=root CONFIRM_DISPOSABLE=yes \
#     RAILS_ENV=test bundle exec rails runner script/project_thread_creation_policy_mysql_check.rb
#
# 確認内容: 本番適用済みのスキーマ(BASE_COMMIT)+既存のプロジェクトから適用 / 列の型・NULL 不可・既定値 0 /
# 既存のプロジェクトは全列そのまま・管理者・オーナーのみ(0) / アプリのコードからも管理者・オーナーのみとして読める /
# 表を作り直さない(INSTANT) / db/schema.rb とのスキーマ一致 / 再実行・戻し・途中失敗後の再適用。
# MySQL 8.4 以外では止まる(ALLOW_NON_84=1 で手順そのものの確認用に実行できる)。
require "open3"
require "stringio"

module ProjectThreadCreationPolicyMysqlCheck
  # 本番に適用済みのスキーマ(schema version 20261110300000)を持つ main のコミット(PR #237 のマージ)。
  BASE_COMMIT = "b54cbcc5".freeze
  BASE_VERSION = 20261110300000
  DB = "bms_thread_creation_policy_check_tmp".freeze
  REF_DB = "bms_thread_creation_policy_check_ref_tmp".freeze
  MIGRATIONS = Rails.root.join("db/migrate").to_s
  VERSION = "20261110400000".freeze
  LEGACY_PROJECT_IDS = [1, 2, 3].freeze
  EXPECTED_COLUMN = ["int", "NO", "0"].freeze

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
    check.call("起点: 本番と同じスキーマに thread_creation_policy 列は無く、対象のマイグレーションだけが未適用", !connection.column_exists?(:projects, :visibility) && pending_versions == [VERSION], pending_versions.inspect)

    migrate_up
    column = policy_column
    check.call("適用: 成功し、未適用のマイグレーションが残らない", pending_versions.empty?)
    check.call("適用: thread_creation_policy は int・NULL 不可・既定値 0", column == EXPECTED_COLUMN, column.inspect)
    check.call("適用: 表を作り直していない(INSTANT で行バージョンが1つ増える)", row_versions == versions_before + 1, "TOTAL_ROW_VERSIONS #{versions_before} → #{row_versions}")
    after = legacy_rows
    check.call("既存のプロジェクト: 件数・ID・名前・所属・日時はそのまま", after.map { |row| row.first(before.first.size) } == before, after.inspect)
    check.call("既存のプロジェクト: すべて管理者・オーナーのみ(0)", after.all? { |row| row.last.to_i == 0 })

    Project.reset_column_information
    legacy = Project.where(id: LEGACY_PROJECT_IDS).order(:id).to_a
    check.call("アプリ: 既存のプロジェクトは管理者・オーナーのみとして読める", legacy.size == 3 && legacy.all?(&:thread_creation_owners_only?))

    app_checks(check)

    check.call("スキーマ: マイグレーション結果が db/schema.rb と一致", dump_schema == reference_schema)

    migrate_up
    check.call("再実行: もう一度 migrate しても何も起きない", pending_versions.empty? && policy_column == EXPECTED_COLUMN)

    ActiveRecord::Migration.suppress_messages { context.down(BASE_VERSION) }
    rows_after_down = legacy_rows
    check.call("戻し: down で列だけ消え、既存のプロジェクトは残る", !connection.column_exists?(:projects, :thread_creation_policy) && rows_after_down == before)

    # MySQL の DDL は巻き戻らないため、列の追加後・記録前に止まった状態を作ってから再実行する。
    connection.add_column(:projects, :thread_creation_policy, :integer, default: 0, null: false)
    migrate_up
    check.call("途中失敗後: 列だけ先に追加され記録が無い状態からでも再実行できる", pending_versions.empty? && policy_column == EXPECTED_COLUMN)

    puts(results.all? ? "結果: すべて OK" : "結果: NG あり")
    results.all?
  end

  def app_checks(check)
    project = Project.find(1)
    stored = { "managers" => 1, "all_members" => 2, "owners_only" => 0 }.map do |policy, value|
      project.update!(thread_creation_policy: policy)
      connection.select_value("SELECT thread_creation_policy FROM projects WHERE id = 1").to_i == value && project.reload.thread_creation_policy == policy
    end
    check.call("アプリ: 運営者まで=1・参加メンバー全員=2・管理者・オーナーのみ=0 で保存・再読込できる", stored.all?)

    created = Project.create!(community_id: 1, customer_id: 1, title: "新規")
    check.call("アプリ: 新しいプロジェクトの既定は管理者・オーナーのみ", created.reload.thread_creation_owners_only?)
    created.destroy!
    # 保存で更新日時が変わるため、戻しの確認(既存の行がそのまま残るか)に備えて元の値に戻す。
    connection.execute("UPDATE projects SET updated_at = created_at WHERE id = 1")
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

  # 対象より後に追加されたマイグレーションは、この検証の対象外にする(後の PR で増えても判定が変わらないように)。
  def pending_versions
    targets = context.migrations.select { |m| m.version <= VERSION.to_i }.map { |m| m.version.to_s }
    targets - connection.select_values("SELECT version FROM schema_migrations").map(&:to_s)
  end

  def base_schema
    out, status = Open3.capture2("git", "-C", Rails.root.to_s, "show", "#{BASE_COMMIT}:db/schema.rb")
    abort "git show #{BASE_COMMIT}:db/schema.rb に失敗しました" unless status.success?
    out
  end

  # 本番と同じ main 時点のスキーマに、既存のプロジェクト(スレッド作成の設定列が無い時代の行)を入れる。
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
    c.execute("INSERT INTO customers (id, email, joined_on, created_at, updated_at) VALUES (1, 'u1@example.com', '2026-01-01', #{now}, #{now})")
    LEGACY_PROJECT_IDS.each do |id|
      c.execute("INSERT INTO projects (id, community_id, customer_id, title, description, status, join_approval_mode, visibility, created_at, updated_at) VALUES (#{id}, 1, 1, 'p#{id}', 'd#{id}', #{id - 1}, #{id % 2}, #{id % 2}, '2026-11-0#{id} 10:00:00', '2026-11-0#{id} 10:00:00')")
    end
    c.execute("SET FOREIGN_KEY_CHECKS=1")
  end

  def legacy_rows
    columns = "id, community_id, customer_id, title, description, status, join_approval_mode, visibility, DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s'), DATE_FORMAT(updated_at, '%Y-%m-%d %H:%i:%s')"
    columns += ", thread_creation_policy" if connection.column_exists?(:projects, :thread_creation_policy)
    connection.select_rows("SELECT #{columns} FROM projects WHERE id IN (#{LEGACY_PROJECT_IDS.join(', ')}) ORDER BY id")
  end

  def policy_column
    connection.select_rows(<<~SQL).first
      SELECT DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'projects' AND COLUMN_NAME = 'thread_creation_policy'
    SQL
  end

  def row_versions
    connection.select_value(<<~SQL).to_i
      SELECT TOTAL_ROW_VERSIONS FROM information_schema.INNODB_TABLES WHERE NAME = CONCAT(DATABASE(), '/projects')
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
exit(ProjectThreadCreationPolicyMysqlCheck.run ? 0 : 1)
