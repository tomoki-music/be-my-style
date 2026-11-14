# プライベートプロジェクトの招待リンク(20261114100000)を、使い捨ての MySQL で検証する。
# 本番・開発の DB には使わない。指定したサーバーに専用の DB を作り、終了時に削除する。
#
#   CHECK_MYSQL_HOST=127.0.0.1 CHECK_MYSQL_PORT=3307 CHECK_MYSQL_USER=root CONFIRM_DISPOSABLE=yes \
#     RAILS_ENV=test bundle exec rails runner script/project_invitation_links_mysql_check.rb
#
# 確認内容: 本番適用済みのスキーマ(BASE_COMMIT)+既存の招待先・プロジェクトから適用 / 新しい表の列・一意索引・外部キー /
# business_signup_invitations の列追加(NULL 可)と既存行の保持 / 既存のプロジェクト(公開範囲)はそのまま /
# アプリのコードからリンクの発行・照合・無効化ができる / 会員・リンクの削除で参照が NULL になる /
# db/schema.rb にも同じ定義がある / 再実行・戻し・途中失敗後の再適用。
# 後の PR でマイグレーションが増えても結果が変わらないよう、比べるのはこの変更の対象だけにしている。
# MySQL 8.4 以外では止まる(ALLOW_NON_84=1 で手順そのものの確認用に実行できる)。
require "open3"
require "stringio"

module ProjectInvitationLinksMysqlCheck
  # 本番に適用済みのスキーマ(schema version 20261113100000)を持つ main のコミット(PR #243 のマージ)。
  BASE_COMMIT = "92c4c286".freeze
  BASE_VERSION = 20261113100000
  DB = "bms_project_invitation_links_check_tmp".freeze
  MIGRATIONS = Rails.root.join("db/migrate").to_s
  VERSION = "20261114100000".freeze
  LEGACY_PROJECT_IDS = [1, 2].freeze

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
    puts "MySQL #{connection.select_value('SELECT VERSION()')} / 起点 #{BASE_COMMIT} / 対象 #{VERSION}"

    fresh_db!
    projects_before = legacy_projects
    invitations_before = legacy_invitations
    check.call("起点: 招待リンクの表・列は無く、対象のマイグレーションだけが未適用",
               !connection.table_exists?(:project_invitation_links) &&
                 !connection.column_exists?(:business_signup_invitations, :project_invitation_link_id) &&
                 pending_versions == [VERSION], pending_versions.inspect)

    migrate_up
    check.call("適用: 成功し、未適用のマイグレーションが残らない", pending_versions.empty?)
    structure_checks(check)
    check.call("既存のプロジェクト: 件数・公開範囲・名前はそのまま", legacy_projects == projects_before, legacy_projects.inspect)
    check.call("既存の招待先: 行はそのままで、招待リンクは NULL", legacy_invitations == invitations_before.map { |row| row + [nil] }, legacy_invitations.inspect)

    app_checks(check)

    schema_rb = File.read(Rails.root.join("db/schema.rb"))
    dumped = dump_schema
    check.call("スキーマ: db/schema.rb の project_invitation_links が実際の表と同じ", table_block(schema_rb, "project_invitation_links") == table_block(dumped, "project_invitation_links"))
    check.call("スキーマ: db/schema.rb の business_signup_invitations が実際の表と同じ", table_block(schema_rb, "business_signup_invitations") == table_block(dumped, "business_signup_invitations"))
    expected_fks = foreign_key_lines(dumped)
    check.call("スキーマ: db/schema.rb の外部キーが実際の表と同じ", expected_fks.size == 3 && (expected_fks - foreign_key_lines(schema_rb)).empty?, expected_fks.inspect)

    migrate_up
    check.call("再実行: もう一度 migrate しても何も起きない", pending_versions.empty? && connection.table_exists?(:project_invitation_links))

    ActiveRecord::Migration.suppress_messages { context.down(BASE_VERSION) }
    check.call("戻し: down で表と列だけ消え、既存の行は残る",
               !connection.table_exists?(:project_invitation_links) &&
                 !connection.column_exists?(:business_signup_invitations, :project_invitation_link_id) &&
                 legacy_projects == projects_before && legacy_invitations == invitations_before)

    # MySQL の DDL は巻き戻らないため、表だけ作られ索引・外部キー・列追加の前に止まった状態から再実行する。
    connection.create_table(:project_invitation_links) do |t|
      t.references :project, null: false, foreign_key: true
      t.string :token_digest, null: false, limit: 64
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.bigint :created_by_id
      t.integer :used_count, null: false, default: 0
      t.datetime :last_used_at
      t.timestamps
    end
    migrate_up
    check.call("途中失敗後: 表だけ先に作られ記録が無い状態からでも再実行でき、同じ構造になる", pending_versions.empty? && structure_ok?)

    puts(results.all? ? "結果: すべて OK" : "結果: NG あり")
    results.all?
  end

  def structure_checks(check)
    columns = column_rows("project_invitation_links")
    check.call("新しい表: token_digest は varchar(64)・NULL 不可", columns["token_digest"] == ["varchar(64)", "NO", nil], columns["token_digest"].inspect)
    check.call("新しい表: expires_at は NULL 不可、revoked_at は NULL 可", columns["expires_at"]&.at(1) == "NO" && columns["revoked_at"]&.at(1) == "YES")
    check.call("新しい表: used_count は int・NULL 不可・既定値 0", columns["used_count"] == ["int", "NO", "0"], columns["used_count"].inspect)
    check.call("新しい表: token_digest に一意索引", unique_index?("project_invitation_links", "token_digest"))
    link_column = column_rows("business_signup_invitations")["project_invitation_link_id"]
    check.call("招待先: project_invitation_link_id は bigint・NULL 可", link_column == ["bigint", "YES", nil], link_column.inspect)
    fks = foreign_keys
    check.call("外部キー: project_id → projects / created_by_id → customers(削除で NULL) / 招待先 → リンク(削除で NULL)",
               fks.include?(%w[project_invitation_links project_id projects NO\ ACTION]) &&
                 fks.include?(%w[project_invitation_links created_by_id customers SET\ NULL]) &&
                 fks.include?(%w[business_signup_invitations project_invitation_link_id project_invitation_links SET\ NULL]), fks.inspect)
  end

  def structure_ok?
    column_rows("project_invitation_links")["used_count"] == ["int", "NO", "0"] &&
      unique_index?("project_invitation_links", "token_digest") &&
      column_rows("business_signup_invitations")["project_invitation_link_id"] == ["bigint", "YES", nil] &&
      foreign_keys.size == 3
  end

  def app_checks(check)
    [Project, ProjectInvitationLink, BusinessSignupInvitation, Customer].each(&:reset_column_information)
    project = Project.find(1)
    project.update_columns(visibility: Project.visibilities[:private])
    link, token = ProjectInvitationLink.issue!(project: project, created_by: Customer.find(1))
    stored_digest = connection.select_value("SELECT token_digest FROM project_invitation_links WHERE id = #{link.id}")
    check.call("アプリ: 発行したリンクはトークンで照合でき、DB にはダイジェストだけが入る",
               ProjectInvitationLink.find_by_token(token) == link && link.usable? && stored_digest == ProjectInvitationLink.digest(token) && stored_digest != token)

    duplicate = begin
      connection.execute("INSERT INTO project_invitation_links (project_id, token_digest, expires_at, created_at, updated_at) VALUES (1, '#{stored_digest}', NOW(), NOW(), NOW())")
      false
    rescue ActiveRecord::RecordNotUnique
      true
    end
    check.call("アプリ: 同じダイジェストは一意索引で入らない", duplicate)

    second, = ProjectInvitationLink.issue!(project: project, created_by: nil)
    check.call("アプリ: 再発行で前のリンクは無効、新しいリンクだけ有効", link.reload.status == :revoked && second.usable?)

    invitation = BusinessSignupInvitation.find_by!(customer_id: 2)
    invitation.update!(project_invitation_link: second)
    connection.execute("DELETE FROM project_invitation_links WHERE id = #{second.id}")
    check.call("外部キー: リンクの行が消えると、招待先の参照は NULL になる(招待先の行は残る)", invitation.reload.project_invitation_link_id.nil?)

    third, = ProjectInvitationLink.issue!(project: project, created_by: Customer.find(3))
    connection.execute("DELETE FROM customers WHERE id = 3")
    check.call("外部キー: 発行した会員の行が消えると、リンクの発行者は NULL になる(リンクは残る)", third.reload.created_by_id.nil?)

    project.destroy!
    check.call("アプリ: プロジェクトを削除すると、そのリンクも削除される", ProjectInvitationLink.where(project_id: 1).none?)
    # 戻しの確認(既存の行がそのまま残るか)に備えて、削除したプロジェクトを入れ直す。
    seed_project(1)
    connection.execute("DELETE FROM project_invitation_links")
  end

  def guard!
    abort "CONFIRM_DISPOSABLE=yes を指定してください(使い捨ての MySQL にだけ使う)" unless ENV["CONFIRM_DISPOSABLE"] == "yes"
    abort "production 環境では実行しない" if Rails.env.production?
    host = ENV["CHECK_MYSQL_HOST"].to_s
    abort "CHECK_MYSQL_HOST を指定してください" if host.empty?
    abort "RDS のエンドポイントには実行しない" if host.include?("rds.amazonaws.com")
    abort "アプリの DB_HOST と同じホストには実行しない" if host == ENV["DB_HOST"].to_s
    existing = server.select_values("SHOW DATABASES").map(&:to_s) & [DB]
    abort "#{existing.join(', ')} が既にあります。前回の残りなら中身を確認してから削除してください" if existing.any?
    version = server.select_value("SELECT VERSION()").to_s
    abort "MySQL #{version} です(8.4 で検証する。手順の確認だけなら ALLOW_NON_84=1)" unless version.start_with?("8.4.") || ENV["ALLOW_NON_84"] == "1"
  end

  def connection_config(database = nil)
    {
      adapter: "mysql2", encoding: "utf8mb4", collation: "utf8mb4_0900_ai_ci",
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

  # 本番と同じ main 時点のスキーマに、既存のプロジェクト(通常公開・限定公開)と招待先(招待用URLから登録した人)を入れる。
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
    [1, 2, 3].each do |id|
      c.execute("INSERT INTO customers (id, email, joined_on, created_at, updated_at) VALUES (#{id}, 'u#{id}@example.com', '2026-01-01', #{now}, #{now})")
    end
    LEGACY_PROJECT_IDS.each { |id| seed_project(id) }
    c.execute("INSERT INTO business_signup_invitations (customer_id, target_type, target_id, expires_at, created_at, updated_at) VALUES (2, 'Project', 2, '2026-12-01 00:00:00', #{now}, #{now})")
    c.execute("SET FOREIGN_KEY_CHECKS=1")
  end

  def seed_project(id)
    connection.execute("INSERT INTO projects (id, community_id, customer_id, title, description, visibility, created_at, updated_at) VALUES (#{id}, 1, 1, 'p#{id}', 'd#{id}', #{id - 1}, '2026-11-0#{id} 10:00:00', '2026-11-0#{id} 10:00:00')")
  end

  def legacy_projects
    connection.select_rows("SELECT id, title, visibility FROM projects WHERE id IN (#{LEGACY_PROJECT_IDS.join(', ')}) ORDER BY id")
  end

  def legacy_invitations
    columns = "customer_id, target_type, target_id, DATE_FORMAT(expires_at, '%Y-%m-%d %H:%i:%s')"
    columns += ", project_invitation_link_id" if connection.column_exists?(:business_signup_invitations, :project_invitation_link_id)
    connection.select_rows("SELECT #{columns} FROM business_signup_invitations ORDER BY customer_id")
  end

  def column_rows(table)
    connection.select_rows(<<~SQL).to_h { |name, type, nullable, default| [name, [type, nullable, default]] }
      SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '#{table}'
    SQL
  end

  def unique_index?(table, column)
    connection.select_values(<<~SQL).include?(0)
      SELECT NON_UNIQUE FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '#{table}' AND COLUMN_NAME = '#{column}'
    SQL
  end

  def foreign_keys
    connection.select_rows(<<~SQL)
      SELECT k.TABLE_NAME, k.COLUMN_NAME, k.REFERENCED_TABLE_NAME, r.DELETE_RULE
      FROM information_schema.KEY_COLUMN_USAGE k
      JOIN information_schema.REFERENTIAL_CONSTRAINTS r
        ON r.CONSTRAINT_SCHEMA = k.CONSTRAINT_SCHEMA AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME
      WHERE k.TABLE_SCHEMA = DATABASE() AND k.REFERENCED_TABLE_NAME IS NOT NULL
        AND (k.TABLE_NAME = 'project_invitation_links' OR k.COLUMN_NAME = 'project_invitation_link_id')
      ORDER BY k.TABLE_NAME, k.COLUMN_NAME
    SQL
  end

  def dump_schema
    io = StringIO.new
    ActiveRecord::SchemaDumper.dump(connection, io)
    io.string
  end

  def table_block(schema, table)
    schema[/^  create_table "#{table}".*?^  end$/m].to_s
  end

  def foreign_key_lines(schema)
    schema.lines.map(&:strip).select do |line|
      line.start_with?('add_foreign_key "project_invitation_links"', 'add_foreign_key "business_signup_invitations", "project_invitation_links"')
    end
  end

  def cleanup!
    # guard! で止まった場合(既存の同名 DB がある等)は何も消さない。
    return unless @created

    use_database(nil)
    connection.execute("DROP DATABASE IF EXISTS #{DB}")
  rescue StandardError => e
    warn "後片付けに失敗しました(#{e.class})。#{DB} を手動で削除してください"
  end
end

ActiveRecord::Base.logger = nil
exit(ProjectInvitationLinksMysqlCheck.run ? 0 : 1)
