# frozen_string_literal: true

# Business のアクセス制御切り替え(プロジェクト内部をコミュニティ参加者に限定)の影響確認。読み取り専用。
#
#   RAILS_ENV=production bundle exec rails runner script/business_access_preflight.rb
#   DETAIL=1 を付けると、対象の行を ID だけで一覧する(氏名・メールアドレスは出さない)。
#
# 現行本番のコード・スキーマ(切り替え前)でもそのまま動くよう、アプリのモデル・新しいテーブルに依存せず
# 既存テーブルを SQL で参照する。新しいテーブルがあれば(切り替え後)その分も集計する。
# 書き込みは Rails(while_preventing_writes)と MySQL(READ ONLY トランザクション)の両方で禁止し、最後に ROLLBACK する。
module BusinessAccessPreflight
  DETAIL_LIMIT = 200

  module_function

  def run(detail: ENV["DETAIL"] == "1")
    connection = ActiveRecord::Base.connection
    output = []

    ActiveRecord::Base.while_preventing_writes do
      connection.execute("SET SESSION TRANSACTION READ ONLY") if mysql?(connection)
      connection.transaction do
        output = Report.new(connection, detail: detail).lines
        raise ActiveRecord::Rollback
      end
    ensure
      connection.execute("SET SESSION TRANSACTION READ WRITE") if mysql?(connection)
    end

    output
  end

  def mysql?(connection)
    connection.adapter_name.match?(/mysql/i)
  end

  class Report
    def initialize(connection, detail:)
      @connection = connection
      @detail = detail
      @true = connection.quoted_true
    end

    def lines
      @lines = []
      business_id = value("SELECT id FROM domains WHERE name = 'business'")
      return ["[business_access:preflight] business ドメインが見つかりません"] if business_id.nil?

      @business_id = Integer(business_id)
      overview
      affected_project_members
      affected_project_creators
      integrity
      after_switch if table?("project_threads")
      @lines
    end

    private

    attr_reader :connection

    def overview
      puts_line "[business_access:preflight] env=#{Rails.env} adapter=#{connection.adapter_name} at=#{Time.current.iso8601}"
      puts_line "  business_communities=#{count("communities c WHERE #{business_community('c')}")}"
      puts_line "  business_projects=#{count("projects p JOIN communities c ON c.id = p.community_id WHERE #{business_community('c')}")}"
      puts_line "  project_members=#{count("project_members pm #{project_join} WHERE #{business_community('c')}")}" \
                " community_members=#{count("community_customers cc JOIN communities c ON c.id = cc.community_id WHERE #{business_community('c')}")}" \
                " pending_permits=#{count("permits pe JOIN communities c ON c.id = pe.community_id WHERE #{business_community('c')}")}"
    end

    # プロジェクトに参加しているが、親コミュニティの参加者でも運営者・admin でもない(=切り替え後は内部を閲覧できない)行。
    def affected_project_members
      rows = select(<<~SQL)
        SELECT pm.project_id, p.community_id, pm.customer_id, #{category_sql('pm.customer_id', 'p.community_id')} AS category
        FROM project_members pm
        #{project_join}
        JOIN customers cu ON cu.id = pm.customer_id
        WHERE #{business_community('c')}
          AND NOT #{community_member_exists('pm.customer_id', 'p.community_id')}
          AND NOT #{community_manager_exists('pm.customer_id', 'c')}
        ORDER BY p.community_id, pm.project_id, pm.customer_id
      SQL

      puts_line ""
      puts_line "■ プロジェクト参加者のうち、コミュニティ参加資格が無い人(切り替え後はプロジェクト内部を閲覧できない)"
      summarize(rows, key: "customer_id")
    end

    # コミュニティ参加資格が無いプロジェクト作成者(切り替え後はプロジェクトの管理・閲覧ができない)。
    def affected_project_creators
      rows = select(<<~SQL)
        SELECT p.id AS project_id, p.community_id, p.customer_id, #{category_sql('p.customer_id', 'p.community_id')} AS category
        FROM projects p
        JOIN communities c ON c.id = p.community_id
        JOIN customers cu ON cu.id = p.customer_id
        WHERE #{business_community('c')}
          AND NOT #{community_member_exists('p.customer_id', 'p.community_id')}
          AND NOT #{community_manager_exists('p.customer_id', 'c')}
        ORDER BY p.community_id, p.id
      SQL

      puts_line ""
      puts_line "■ コミュニティ参加資格が無いプロジェクト作成者(切り替え後は管理者として扱わない)"
      summarize(rows, key: "customer_id")
    end

    def integrity
      puts_line ""
      puts_line "■ データの整合性(Business 分)"
      puts_line "  duplicate_community_members=#{duplicates('community_customers', 'community_id')}" \
                " duplicate_permits=#{duplicates('permits', 'community_id')}" \
                " duplicate_project_members=#{duplicate_project_members}"
      puts_line "  permits_of_existing_members=#{count(<<~SQL.squish)}"
        permits pe JOIN communities c ON c.id = pe.community_id
        WHERE #{business_community('c')} AND #{community_member_exists('pe.customer_id', 'pe.community_id')}
      SQL
      puts_line "  communities_without_active_manager=#{count(<<~SQL.squish)}"
        communities c WHERE #{business_community('c')}
          AND NOT EXISTS (SELECT 1 FROM customers o WHERE o.id = c.owner_id AND #{active('o')})
          AND NOT EXISTS (SELECT 1 FROM community_owners co JOIN customers o ON o.id = co.customer_id
                          WHERE co.community_id = c.id AND #{active('o')})
      SQL
    end

    # 切り替え後(新しいテーブルがある場合)だけの確認。旧コードが残したデータ(画面表示時・backfill で補う)の残数。
    def after_switch
      general = column?("project_threads", "general") ? "AND t.general = #{@true}" : ""
      unthreaded_projects = select(<<~SQL).map { |row| row["project_id"] }
        SELECT DISTINCT project_id FROM project_chats WHERE project_thread_id IS NULL ORDER BY project_id
      SQL
      without_general = select(<<~SQL).map { |row| row["id"] }
        SELECT p.id FROM projects p JOIN communities c ON c.id = p.community_id
        WHERE #{business_community('c')} AND NOT EXISTS (SELECT 1 FROM project_threads t WHERE t.project_id = p.id #{general})
        ORDER BY p.id
      SQL

      puts_line ""
      puts_line "■ 切り替え後の確認(0 が正常。0 でなければ rails business_project_threads:backfill を実行)"
      puts_line "  project_threads=#{count('project_threads')} unthreaded_project_chats=#{count('project_chats WHERE project_thread_id IS NULL')}" \
                " projects_with_unthreaded_chats=#{unthreaded_projects.size} business_projects_without_general_thread=#{without_general.size}"
      puts_line "    unthreaded project_ids=#{unthreaded_projects.first(DETAIL_LIMIT).join(',')}" if unthreaded_projects.any?
      puts_line "    without_general_thread project_ids=#{without_general.first(DETAIL_LIMIT).join(',')}" if without_general.any?
      return unless table?("community_access_suspensions")

      puts_line "  community_access_suspensions=#{count('community_access_suspensions')}" \
                " project_access_suspensions=#{count('project_access_suspensions')}" \
                " project_join_requests=#{count('project_join_requests')}"
    end

    # 単純に承認してはいけない人を分けて数える(上から順に判定)。
    #   withdrawn           : 退会済み(ログインできない。承認しない)
    #   community_suspended : コミュニティのアクセス停止中(切り替え後のみ。承認しない)
    #   unconfirmed         : メール未確認(ログインできない)
    #   permit_pending      : コミュニティへ参加申請中(運営者が通常の承認画面で判断)
    #   not_in_community    : 申請も無い(退出・運営者による除外の可能性。個別に確認)
    def category_sql(customer_column, community_column)
      suspended =
        if table?("community_access_suspensions")
          "WHEN EXISTS (SELECT 1 FROM community_access_suspensions s WHERE s.customer_id = #{customer_column} AND s.community_id = #{community_column}) THEN 'community_suspended'"
        end

      <<~SQL.squish
        CASE
          WHEN cu.is_deleted = #{@true} THEN 'withdrawn'
          #{suspended}
          WHEN cu.confirmed_at IS NULL THEN 'unconfirmed'
          WHEN EXISTS (SELECT 1 FROM permits pe WHERE pe.customer_id = #{customer_column} AND pe.community_id = #{community_column}) THEN 'permit_pending'
          ELSE 'not_in_community'
        END
      SQL
    end

    def summarize(rows, key:)
      customers = rows.map { |row| row[key] }.uniq
      puts_line "  rows=#{rows.size} communities=#{rows.map { |row| row['community_id'] }.uniq.size}" \
                " projects=#{rows.map { |row| row['project_id'] }.uniq.size} customers=#{customers.size}"
      rows.group_by { |row| row["category"] }.sort.each do |category, category_rows|
        puts_line "    #{category}: rows=#{category_rows.size} customers=#{category_rows.map { |row| row[key] }.uniq.size}"
      end
      rows.group_by { |row| row["community_id"] }.each do |community_id, community_rows|
        puts_line "    community_id=#{community_id} projects=#{community_rows.map { |row| row['project_id'] }.uniq.size}" \
                  " customers=#{community_rows.map { |row| row[key] }.uniq.size}"
      end
      return unless @detail

      rows.first(DETAIL_LIMIT).each do |row|
        puts_line "      community_id=#{row['community_id']} project_id=#{row['project_id']} customer_id=#{row[key]} category=#{row['category']}"
      end
      puts_line "      ... (#{rows.size - DETAIL_LIMIT} 行省略)" if rows.size > DETAIL_LIMIT
    end

    def business_community(alias_name)
      "#{alias_name}.domain_id = #{@business_id}"
    end

    def project_join
      "JOIN projects p ON p.id = pm.project_id JOIN communities c ON c.id = p.community_id"
    end

    def community_member_exists(customer_column, community_column)
      "EXISTS (SELECT 1 FROM community_customers cc WHERE cc.customer_id = #{customer_column} AND cc.community_id = #{community_column})"
    end

    # Customer#can_manage_community? と同じ範囲(admin / コミュニティの owner / community_owners)。
    def community_manager_exists(customer_column, community_alias)
      <<~SQL.squish
        (EXISTS (SELECT 1 FROM customers a WHERE a.id = #{customer_column} AND a.is_owner = 1)
         OR #{community_alias}.owner_id = #{customer_column}
         OR EXISTS (SELECT 1 FROM community_owners co WHERE co.customer_id = #{customer_column} AND co.community_id = #{community_alias}.id))
      SQL
    end

    def active(alias_name)
      "#{alias_name}.is_deleted <> #{@true}"
    end

    def duplicates(table, community_column)
      value(<<~SQL.squish).to_i
        SELECT COUNT(*) FROM (
          SELECT t.#{community_column}, t.customer_id FROM #{table} t JOIN communities c ON c.id = t.#{community_column}
          WHERE #{business_community('c')} GROUP BY t.#{community_column}, t.customer_id HAVING COUNT(*) > 1
        ) d
      SQL
    end

    def duplicate_project_members
      value(<<~SQL.squish).to_i
        SELECT COUNT(*) FROM (
          SELECT pm.project_id, pm.customer_id FROM project_members pm #{project_join}
          WHERE #{business_community('c')} GROUP BY pm.project_id, pm.customer_id HAVING COUNT(*) > 1
        ) d
      SQL
    end

    def table?(name)
      connection.table_exists?(name)
    end

    def column?(table, column)
      connection.column_exists?(table, column)
    end

    def count(from)
      value("SELECT COUNT(*) FROM #{from}").to_i
    end

    def value(sql)
      connection.select_value(sql)
    end

    def select(sql)
      connection.select_all(sql).to_a
    end

    def puts_line(line)
      @lines << line
    end
  end
end

# rails runner で直接実行されたときだけ出力する(rake・spec からは load して BusinessAccessPreflight.run を呼ぶ)。
puts BusinessAccessPreflight.run if $PROGRAM_NAME == __FILE__
