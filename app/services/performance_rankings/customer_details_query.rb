module PerformanceRankings
  # 演奏実績ランキング一覧の「現在ページに載る customer」だけについて、
  # 展開詳細(参加イベント / 演奏した楽曲 / 担当パート)を 1 クエリで構築する。
  #
  # ■ 一覧とのズレ防止
  #   集計対象・除外条件・集計範囲(scope)・集計期間(period)は
  #   PerformanceRankings::RankingQuery と完全に一致させる。
  #   1 演奏の単位も同じ (customer_id, event_id, song_master_id, 正規化パート)。
  #   → 一覧は全期間なのに詳細は今月、一覧はコミュニティ内なのに詳細は全体、を起こさない。
  #
  # ■ パフォーマンス
  #   customer_id 群を IN 条件に入れ、RankingQuery と同じ 2 段構成(派生表で重複排除)の
  #   1 クエリで「1 演奏 = 1 行」を取得する。SongMaster の表示名だけ id 一括取得で 1 クエリ。
  #   行数・ユーザー数に依らずクエリ数は一定。
  class CustomerDetailsQuery
    Detail = Struct.new(:events, :songs, :parts, keyword_init: true)

    # 参加イベント 1 件。play_count = そのイベントでのこのユーザーの演奏数。
    EventLine = Struct.new(:event_id, :name, :held_on, :play_count, keyword_init: true)

    # 演奏した楽曲 1 件(SongMaster 単位)。part_counts = [[パート名, 回数], ...] 回数降順。
    SongLine = Struct.new(:song_master_id, :name, :artist_name, :play_count, :part_counts, keyword_init: true)

    PART_OPTIONS = JoinPart::NAME_OPTIONS

    def initialize(customer_ids:, scope: "all", community_id: nil, period: nil, now: Time.current)
      @customer_ids = Array(customer_ids).map(&:to_i).uniq
      @scope = scope
      @community_id = community_id
      @period = period || Period.new
      @now = now
    end

    # => { customer_id => Detail }
    def call
      return {} if @customer_ids.empty?
      return {} if music_domain_id.blank?
      return {} if @period.invalid?

      records = ActiveRecord::Base.connection.select_all(sql).to_a
      return {} if records.empty?

      masters = SongMaster.where(id: records.map { |r| r["song_master_id"] }.uniq).index_by(&:id)

      records.group_by { |r| r["customer_id"].to_i }.transform_values do |rows|
        Detail.new(
          events: build_events(rows),
          songs: build_songs(rows, masters),
          parts: build_parts(rows)
        )
      end
    end

    private

    # 開催日の降順 → event_id の降順(安定順)。
    def build_events(rows)
      rows
        .group_by { |r| r["event_id"].to_i }
        .map do |event_id, group|
          first = group.first
          EventLine.new(
            event_id: event_id,
            name: first["event_name"],
            held_on: to_date(first["event_start_time"]),
            play_count: group.size
          )
        end
        .sort_by { |line| [-date_key(line.held_on), -line.event_id] }
    end

    # 演奏回数の降順 → 最終演奏日の降順 → SongMaster ID の昇順(安定順)。
    def build_songs(rows, masters)
      rows
        .group_by { |r| r["song_master_id"].to_i }
        .filter_map do |song_master_id, group|
          master = masters[song_master_id]
          next if master.nil?

          last_performed_on = group.filter_map { |r| to_date(r["event_start_time"]) }.max

          [
            SongLine.new(
              song_master_id: song_master_id,
              name: master.song_name,
              artist_name: master.artist_name,
              play_count: group.size,
              part_counts: part_counts(group)
            ),
            last_performed_on
          ]
        end
        .sort_by { |(line, last_performed_on)| [-line.play_count, -date_key(last_performed_on), line.song_master_id] }
        .map(&:first)
    end

    # 担当パートと回数。演奏回数の降順 → NAME_OPTIONS の並び順。0 回は含めない。
    def build_parts(rows)
      part_counts(rows)
    end

    def part_counts(group)
      PART_OPTIONS
        .map { |name| [name, group.count { |r| r["norm"] == name }] }
        .select { |(_, count)| count.positive? }
        .sort_by { |(name, count)| [-count, PART_OPTIONS.index(name)] }
    end

    def date_key(date)
      date ? date.to_time.to_i : 0
    end

    def to_date(value)
      return nil if value.blank?
      return value.to_date if value.respond_to?(:to_date)

      Time.zone.parse(value.to_s)&.to_date
    rescue ArgumentError
      nil
    end

    def sql
      norm = PerformanceHistory::PartNameNormalizer.sql_normalized_name("join_parts.join_part_name")

      conditions = [
        "communities.domain_id = :domain_id",
        "customers.is_deleted = FALSE",
        "songs.song_master_id IS NOT NULL",
        "events.event_end_time <= :now",
        "join_part_customers.customer_id IN (:customer_ids)"
      ]
      binds = { domain_id: music_domain_id, now: @now, customer_ids: @customer_ids }

      if @scope == "community" && @community_id.present?
        conditions << "events.community_id = :community_id"
        binds[:community_id] = @community_id
      end

      if (range = @period.range)
        if range.first
          conditions << "events.event_start_time >= :from"
          binds[:from] = range.first
        end
        if range.last
          conditions << "events.event_start_time < :to"
          binds[:to] = range.last
        end
      end

      # 内側で (customer, event, song_master, 正規化パート) 単位に GROUP BY = 1 演奏 1 行。
      # 外側は norm が突合できた行だけを残す(RankingQuery と同じ 2 段構成)。
      sql = <<~SQL.squish
        SELECT
          base.customer_id AS customer_id,
          base.event_id AS event_id,
          base.event_name AS event_name,
          base.event_start_time AS event_start_time,
          base.song_master_id AS song_master_id,
          base.norm AS norm
        FROM (
          SELECT
            join_part_customers.customer_id AS customer_id,
            songs.event_id AS event_id,
            events.event_name AS event_name,
            events.event_start_time AS event_start_time,
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
            events.event_name,
            events.event_start_time,
            songs.song_master_id,
            norm
        ) AS base
        WHERE base.norm IS NOT NULL
      SQL

      ActiveRecord::Base.sanitize_sql_array([sql, binds])
    end

    def music_domain_id
      return @music_domain_id if defined?(@music_domain_id)

      @music_domain_id = Domain.find_by(name: "music")&.id
    end
  end
end
