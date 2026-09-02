module PerformanceRankings
  # 演奏実績ランキングの集計。ランキングの主役は「楽曲」ではなく「ユーザー」。
  # 1 行 = 1 人の customer で、その人の演奏活動量を比較する。
  #
  # ■ 集計対象(既存「演奏実績」と同一定義)
  #   正データは PerformanceHistory::ProfileQuery / ExperiencedCustomersQuery と同じく、
  #   「終了済みイベントに現存する JoinPartCustomer」。
  #     - events.event_end_time <= now(開催前・開催中は対象外)
  #     - songs.song_master_id が解決済み(名寄せ不能な旧データは対象外。プロフィール画面と同じ)
  #     - customers.is_deleted = FALSE(退会ユーザーはランキングに載せない)
  #     - パート名は PerformanceHistory::PartNameNormalizer で正規化。突合不能なら対象外
  #   1 演奏の単位は (customer_id, event_id, song_master_id, 正規化パート)。
  #   同一ユーザー・同一イベント・同一曲で Vo と Gt を兼任すれば 2 演奏。
  #   同一ユーザー・同一イベント・同一曲・同一パートの重複データは 1 演奏へ潰す。
  #
  # ■ 2 種類のランキング軸
  #   :performances … 演奏数(= 上記 1 単位の件数)の降順
  #   :events       … 参加イベント数(有効な演奏実績を持つ異なる event_id 数)の降順
  #   競技順位はいずれも「主値のみ」で採番する(1,2,2,4…)。
  #   演奏楽曲数・パート別回数は独立ランキングにせず、各ユーザーのサマリー値として表示する。
  #
  # ■ 公開範囲
  #   music ドメインのコミュニティに属するイベントのみ。イベント・コミュニティには
  #   下書き / 非公開 / 論理削除の状態カラムが無く(成立楽曲ランキング PR #176 と同じ前提)、
  #   コミュニティ詳細・イベント詳細・メンバー一覧はログイン中の music ユーザーなら誰でも
  #   閲覧できる。したがって「全体」= 全 music コミュニティ、「コミュニティ内」= 指定コミュニティ。
  #   閲覧はログイン必須(氏名・プロフィール画像を表示するため。メンバー一覧と同じ扱い)。
  #
  # ■ パフォーマンス
  #   集計は派生表 + GROUP BY の 1 クエリ。Ruby 側で読むのは「実績のある customer 数」分の
  #   集約済み行のみ。順位付け後、表示ページ分の Customer だけを画像添付付きで 1 クエリ取得し、
  #   同じページ分の展開詳細(参加イベント / 演奏楽曲 / 担当パート)も 1 クエリで一括取得する
  #   (行ごとの追加クエリなし)。
  class RankingQuery
    KINDS = %w[performances events].freeze
    DEFAULT_KIND = "performances".freeze
    SCOPES = %w[all community].freeze
    DEFAULT_SCOPE = "all".freeze
    PART_OPTIONS = JoinPart::NAME_OPTIONS
    DEFAULT_PER = 50
    MAX_PER = 100

    Row = Struct.new(
      :rank,
      :customer_id,
      :customer,
      :play_count,
      :event_count,
      :song_count,
      :part_breakdown,
      :detail,
      keyword_init: true
    ) do
      # 内訳が最も多いパート(同数は JoinPart::NAME_OPTIONS の並び順で安定)。実績が無ければ nil。
      def primary_part
        best = sorted_part_breakdown.first
        best&.first
      end

      # [パート名, 回数] を「回数の降順 → NAME_OPTIONS 順」で。0 回は含めない。
      def sorted_part_breakdown
        options = PerformanceRankings::RankingQuery::PART_OPTIONS
        options
          .map { |name| [name, part_breakdown[name].to_i] }
          .select { |(_, count)| count.positive? }
          .sort_by { |(name, count)| [-count, options.index(name)] }
      end
    end

    def initialize(kind: nil, scope: nil, community_id: nil, period: nil, page: nil, per: nil, now: Time.current)
      @raw_kind = kind
      @raw_scope = scope
      @raw_community_id = community_id
      @period = period || Period.new
      @raw_page = page
      @raw_per = per
      @now = now
    end

    # --- 正規化済みパラメータ(フォーム復元にも使う) --------------------------------

    def kind
      @kind ||= KINDS.include?(@raw_kind.to_s) ? @raw_kind.to_s : DEFAULT_KIND
    end

    def scope
      @scope ||= begin
        requested = SCOPES.include?(@raw_scope.to_s) ? @raw_scope.to_s : DEFAULT_SCOPE
        # 実在する music コミュニティが選ばれていなければ全体に倒す(URL 改ざん対策)。
        requested == "community" && community.present? ? "community" : "all"
      end
    end

    def period
      @period
    end

    # 実在し、かつ music ドメインのコミュニティのみ採用する。
    def community
      return @community if defined?(@community)

      value = @raw_community_id.to_s.strip
      @community =
        if value.match?(/\A\d+\z/) && music_domain_id.present?
          Community.find_by(id: value.to_i, domain_id: music_domain_id)
        end
    end

    def community_id
      community&.id
    end

    def events_kind?
      kind == "events"
    end

    def period_invalid?
      period.invalid?
    end

    def page
      @page ||= [@raw_page.to_i, 1].max
    end

    def per
      @per ||= begin
        value = @raw_per.to_i
        value.positive? ? value.clamp(1, MAX_PER) : DEFAULT_PER
      end
    end

    # --- フィルター選択肢 ---------------------------------------------------------

    def community_options
      @community_options ||=
        music_domain_id ? Community.where(domain_id: music_domain_id).order(:name).pluck(:name, :id) : []
    end

    # --- 集計結果 ---------------------------------------------------------------

    # 競技順位付きの Row を Kaminari でページングして返す。
    def rows
      @rows ||= begin
        collection = Kaminari.paginate_array(ranked_rows, total_count: ranked_rows.size)
                             .page(page)
                             .per(per)
        attach_customers!(collection)
        attach_details!(collection)
        collection
      end
    end

    def total_participant_count
      ranked_rows.size
    end

    # のべ演奏回数(全 customer の演奏回数合計)。空状態の判定・サマリー表示に使う。
    def total_play_count
      ranked_rows.sum(&:play_count)
    end

    private

    # 表示順を決定的にする:
    #   1. 主値の降順   2. 補助値の降順   3. 異なる楽曲数の降順   4. customer_id の昇順
    def sorted_rows
      @sorted_rows ||= aggregated_rows.sort_by do |row|
        [-primary_value(row), -secondary_value(row), -row[:song_count], row[:customer_id]]
      end
    end

    def ranked_rows
      @ranked_rows ||= begin
        result = []
        sorted_rows.each_with_index do |row, index|
          rank =
            if index.positive? && primary_value(sorted_rows[index - 1]) == primary_value(row)
              result.last.rank
            else
              index + 1
            end

          result << Row.new(
            rank: rank,
            customer_id: row[:customer_id],
            customer: nil,
            play_count: row[:play_count],
            event_count: row[:event_count],
            song_count: row[:song_count],
            part_breakdown: row[:part_breakdown],
            detail: nil
          )
        end
        result
      end
    end

    # 競技順位の基準。演奏数ランキング=演奏数、参加イベント数ランキング=参加イベント数。
    def primary_value(row)
      events_kind? ? row[:event_count] : row[:play_count]
    end

    # 同率時の第 1 タイブレーク(もう一方の主値)。
    def secondary_value(row)
      events_kind? ? row[:play_count] : row[:event_count]
    end

    # SQL 集計結果を Ruby の Hash 配列へ。
    def aggregated_rows
      @aggregated_rows ||= aggregation.map do |record|
        breakdown = PART_OPTIONS.index_with { |name| record["cnt_#{name.downcase}"].to_i }
        {
          customer_id: record["customer_id"].to_i,
          play_count: record["play_count"].to_i,
          event_count: record["event_count"].to_i,
          song_count: record["song_count"].to_i,
          part_breakdown: breakdown
        }
      end
    end

    def aggregation
      @aggregation ||= begin
        return [] if music_domain_id.blank?
        return [] if period_invalid?

        ActiveRecord::Base.connection.select_all(aggregation_sql).to_a
      end
    end

    def aggregation_sql
      norm = PerformanceHistory::PartNameNormalizer.sql_normalized_name("join_parts.join_part_name")

      conditions = [
        "communities.domain_id = :domain_id",
        "customers.is_deleted = FALSE",
        "songs.song_master_id IS NOT NULL",
        "events.event_end_time <= :now"
      ]
      binds = { domain_id: music_domain_id, now: @now }

      if scope == "community"
        conditions << "events.community_id = :community_id"
        binds[:community_id] = community_id
      end

      if (range = period.range)
        if range.first
          conditions << "events.event_start_time >= :from"
          binds[:from] = range.first
        end
        if range.last
          conditions << "events.event_start_time < :to"
          binds[:to] = range.last
        end
      end

      part_breakdown_selects = PART_OPTIONS.map do |name|
        "SUM(CASE WHEN base.norm = #{ActiveRecord::Base.connection.quote(name)} THEN 1 ELSE 0 END) AS cnt_#{name.downcase}"
      end.join(",\n          ")

      # 内側のクエリで (customer, event, song_master, 正規化パート) 単位に GROUP BY して
      # 重複エントリーを 1 行へ潰す。外側は customer ごとに件数・DISTINCT イベント数・
      # DISTINCT 楽曲数を数えるだけ。
      # SQLite(テスト)/ MySQL(本番)の両対応のため、複合キーの COUNT(DISTINCT ...) や
      # CONCAT_WS を使わずこの 2 段構成にする。
      sql = <<~SQL.squish
        SELECT
          base.customer_id AS customer_id,
          COUNT(*) AS play_count,
          COUNT(DISTINCT base.event_id) AS event_count,
          COUNT(DISTINCT base.song_master_id) AS song_count,
          #{part_breakdown_selects}
        FROM (
          SELECT
            join_part_customers.customer_id AS customer_id,
            songs.event_id AS event_id,
            songs.song_master_id AS song_master_id,
            #{norm} AS norm
          FROM join_part_customers
          INNER JOIN join_parts ON join_parts.id = join_part_customers.join_part_id
          INNER JOIN songs ON songs.id = join_parts.song_id
          INNER JOIN events ON events.id = songs.event_id
          INNER JOIN communities ON communities.id = events.community_id
          INNER JOIN customers ON customers.id = join_part_customers.customer_id
          WHERE #{conditions.join(' AND ')}
          GROUP BY
            join_part_customers.customer_id,
            songs.event_id,
            songs.song_master_id,
            norm
        ) AS base
        WHERE base.norm IS NOT NULL
        GROUP BY base.customer_id
      SQL

      ActiveRecord::Base.sanitize_sql_array([sql, binds])
    end

    # 現在ページの Row にだけ Customer を割り当てる(画像添付を人数に依らず 2 クエリで先読み)。
    def attach_customers!(collection)
      ids = collection.map(&:customer_id).uniq
      return if ids.empty?

      customers_by_id = Customer.where(id: ids).with_attached_profile_image.index_by(&:id)
      collection.each { |row| row.customer = customers_by_id[row.customer_id] }
      collection.reject! { |row| row.customer.nil? }
    end

    # 現在ページの Row にだけ展開詳細を割り当てる。一覧と同一の scope・period 条件で
    # ページ分をまとめて 1 クエリ取得する(アコーディオンを開くたびの遅延読み込みはしない)。
    def attach_details!(collection)
      ids = collection.map(&:customer_id).uniq
      return if ids.empty?

      details = CustomerDetailsQuery.new(
        customer_ids: ids,
        scope: scope,
        community_id: community_id,
        period: period,
        now: @now
      ).call

      collection.each { |row| row.detail = details[row.customer_id] }
    end

    def music_domain_id
      return @music_domain_id if defined?(@music_domain_id)

      @music_domain_id = Domain.find_by(name: "music")&.id
    end
  end
end
