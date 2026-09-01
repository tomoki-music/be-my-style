module SongRankings
  # 成立楽曲ランキングの集計。
  #
  # ■ 成立の定義
  #   Song#established? と同一基準(現役参加者が0人のパートが1つも無い = 必要パートがすべて埋まった)。
  #   開催予定・開催済みを問わない。退会 customer(customers.is_deleted = TRUE)は現役参加者に数えない。
  #   Song#established? は「パート0件」を true とする既存挙動を保持しているため、ランキングでは
  #   「必要パートが埋まった」の趣旨に沿って別途 HAVING で「パート1件以上」を必須にする。
  #
  # ■ 集計単位
  #   (イベント × SongMaster) ごとに最大1回。COUNT(DISTINCT events.id) で二重計上を防ぐ。
  #   同一イベント内に同じ SongMaster の Song が複数あっても1回。別イベントで成立すればそれぞれ1回。
  #   SongMaster に紐づかない Song(解決失敗)は集計対象外。SongMasterAlias 経由の旧表記は
  #   Song#song_master_id 解決時点(SongMasters::Resolver)で正 SongMaster に寄っているため、
  #   ここでは songs.song_master_id をそのまま信頼する。
  #
  # ■ 公開範囲
  #   music ドメインのコミュニティに属するイベントのみ。イベント・コミュニティには
  #   下書き / 非公開 / キャンセル / 論理削除の状態カラムが存在しないため、
  #   永続化されたイベントはすべて公開対象。個人情報(参加者名など)は集計にも表示にも含めない。
  #
  # ■ パフォーマンス
  #   集計(JOIN / GROUP BY / COUNT(DISTINCT) / HAVING)はすべて1本の SQL で実行する。
  #   Ruby 側で読み込むのは「SongMaster ごとに集約済みの行」だけ(= 成立実績のある楽曲数分)。
  #   競技順位(1,2,2,4…)の採番と表示順の確定は、その集約済み配列に対して行う。
  class RankingQuery
    Row = Struct.new(
      :rank,
      :song_master_id,
      :song_name,
      :artist_name,
      :established_count,
      :representative_song_id,
      :representative_event_id,
      keyword_init: true
    )

    PERIODS = %w[all monthly yearly].freeze
    DEFAULT_PERIOD = "all".freeze
    MIN_YEAR = 2015
    FUTURE_YEAR_ALLOWANCE = 3
    DEFAULT_PER = 50
    MAX_PER = 100
    ARTIST_NAME_MAX_LENGTH = 255

    def initialize(period: nil, year: nil, month: nil, community_id: nil, artist_name: nil, page: nil, per: nil)
      @raw_period = period
      @raw_year = year
      @raw_month = month
      @raw_community_id = community_id
      @raw_artist_name = artist_name
      @raw_page = page
      @raw_per = per
    end

    # --- 正規化済みパラメータ(フォームの選択状態復元にも使う) -------------------------

    def period
      @period ||= PERIODS.include?(@raw_period.to_s) ? @raw_period.to_s : DEFAULT_PERIOD
    end

    def year
      @year ||= begin
        value = @raw_year.to_s.strip
        parsed = value.match?(/\A\d{1,4}\z/) ? value.to_i : Time.zone.today.year
        parsed.clamp(MIN_YEAR, max_year)
      end
    end

    def month
      @month ||= begin
        value = @raw_month.to_s.strip
        parsed = value.match?(/\A\d{1,2}\z/) ? value.to_i : Time.zone.today.month
        parsed.clamp(1, 12)
      end
    end

    # 実在し、かつ公開対象(music ドメイン)のコミュニティ ID のみ採用する。
    # それ以外(存在しない ID・別ドメイン・空・非数値)は「すべてのコミュニティ」に倒す。
    def community_id
      return @community_id if defined?(@community_id)

      value = @raw_community_id.to_s.strip
      @community_id = (value.match?(/\A\d+\z/) && community_options.any? { |(_, id)| id == value.to_i }) ? value.to_i : nil
    end

    # ランキング対象に実在するアーティスト名のみ採用する(完全一致・バインド値として使用)。
    def artist_name
      return @artist_name if defined?(@artist_name)

      value = @raw_artist_name.to_s.strip
      @artist_name = (value.present? && value.length <= ARTIST_NAME_MAX_LENGTH && artist_options.include?(value)) ? value : nil
    end

    def max_year
      Time.zone.today.year + FUTURE_YEAR_ALLOWANCE
    end

    def year_options
      (MIN_YEAR..max_year).to_a.reverse
    end

    def month_options
      (1..12).to_a
    end

    def filtered?
      period != DEFAULT_PERIOD || community_id.present? || artist_name.present?
    end

    # --- フィルター選択肢 -------------------------------------------------------------

    # 公開対象(music ドメイン)コミュニティを名前順で。イベント一覧の検索セレクトと同じ母集団。
    def community_options
      @community_options ||=
        Community.where(domain_id: music_domain_id).order(:name).pluck(:name, :id)
    end

    # ランキング対象(成立実績あり)に登場するアーティスト名。表記ゆれは SongMaster 側で
    # 正規化済みのものを尊重し、ここでは表示名(artist_name)をそのまま重複排除する。
    def artist_options
      @artist_options ||=
        established_song_masters.filter_map { |m| m.artist_name.presence }.uniq.sort
    end

    # --- 集計結果 -------------------------------------------------------------------

    # 競技順位付きの Row を Kaminari でページングして返す。
    def rows
      @rows ||= begin
        collection = Kaminari.paginate_array(ranked_rows, total_count: ranked_rows.size)
                             .page(page)
                             .per(per)
        attach_representative_events!(collection)
        collection
      end
    end

    def total_master_count
      ranked_rows.size
    end

    def total_established_count
      ranked_rows.sum(&:established_count)
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

    private

    # 表示順を決定的にする: 1.成立回数の降順 2.楽曲名の昇順 3.SongMaster ID の昇順。
    # 楽曲名の照合順序は DB(utf8mb4_0900_ai_ci)と厳密一致はしないが、
    # ここでは「毎回同じ順序になること」を最優先し Ruby の文字列比較で確定させる。
    def sorted_rows
      @sorted_rows ||= aggregated_rows.sort_by { |r| [-r[:established_count], r[:song_name].to_s, r[:song_master_id]] }
    end

    # 競技順位(同数は同順位、次は人数分飛ばす)を採番する。
    def ranked_rows
      @ranked_rows ||= begin
        result = []
        sorted_rows.each_with_index do |row, index|
          rank =
            if index.positive? && sorted_rows[index - 1][:established_count] == row[:established_count]
              result.last.rank
            else
              index + 1
            end
          result << Row.new(
            rank: rank,
            song_master_id: row[:song_master_id],
            song_name: row[:song_name],
            artist_name: row[:artist_name],
            established_count: row[:established_count],
            representative_song_id: row[:representative_song_id],
            representative_event_id: nil
          )
        end
        result
      end
    end

    # 集約済み行(SongMaster 単位)。SQL 側で成立判定・DISTINCT イベント数まで確定させ、
    # SongMaster の表示名とアーティスト絞り込みを Ruby 側で突き合わせる。
    def aggregated_rows
      @aggregated_rows ||= begin
        masters_by_id = established_song_masters.index_by(&:id)
        aggregation.filter_map do |record|
          master = masters_by_id[record["song_master_id"].to_i]
          next if master.nil?
          next if artist_name.present? && master.artist_name.to_s != artist_name

          {
            song_master_id: master.id,
            song_name: master.song_name,
            artist_name: master.artist_name,
            established_count: record["established_count"].to_i,
            representative_song_id: record["representative_song_id"].to_i
          }
        end
      end
    end

    def established_song_masters
      @established_song_masters ||=
        SongMaster.where(id: aggregation.map { |r| r["song_master_id"] }).to_a
    end

    # 成立した (song × event) を SQL で確定し、SongMaster ごとに DISTINCT イベント数を数える。
    # representative_song_id は「成立実績のある Song のうち ID 最大(= 最新登録)」で決定的に選ぶ。
    def aggregation
      @aggregation ||= begin
        return [] if music_domain_id.blank?

        ActiveRecord::Base.connection.select_all(aggregation_sql).to_a
      end
    end

    def aggregation_sql
      conditions = ["songs.song_master_id IS NOT NULL", "communities.domain_id = :domain_id"]
      binds = { domain_id: music_domain_id }

      if community_id.present?
        conditions << "events.community_id = :community_id"
        binds[:community_id] = community_id
      end

      if (range = event_start_range)
        conditions << "events.event_start_time >= :from"
        conditions << "events.event_start_time < :to"
        binds[:from] = range.first
        binds[:to] = range.last
      end

      sql = <<~SQL.squish
        SELECT
          established.song_master_id AS song_master_id,
          COUNT(DISTINCT established.event_id) AS established_count,
          MAX(established.song_id) AS representative_song_id
        FROM (
          SELECT
            songs.id AS song_id,
            songs.event_id AS event_id,
            songs.song_master_id AS song_master_id
          FROM songs
          INNER JOIN events ON events.id = songs.event_id
          INNER JOIN communities ON communities.id = events.community_id
          INNER JOIN join_parts ON join_parts.song_id = songs.id
          LEFT OUTER JOIN join_part_customers ON join_part_customers.join_part_id = join_parts.id
          LEFT OUTER JOIN customers
            ON customers.id = join_part_customers.customer_id
           AND customers.is_deleted = FALSE
          WHERE #{conditions.join(' AND ')}
          GROUP BY songs.id, songs.event_id, songs.song_master_id
          HAVING COUNT(DISTINCT join_parts.id) > 0
             AND COUNT(DISTINCT CASE WHEN customers.id IS NOT NULL THEN join_parts.id END)
               = COUNT(DISTINCT join_parts.id)
        ) AS established
        GROUP BY established.song_master_id
      SQL

      ActiveRecord::Base.sanitize_sql_array([sql, binds])
    end

    # 期間(イベント開催日基準・Asia/Tokyo)。全期間は nil。
    def event_start_range
      case period
      when "monthly"
        from = Time.zone.local(year, month, 1)
        [from, from.next_month]
      when "yearly"
        from = Time.zone.local(year, 1, 1)
        [from, from.next_year]
      end
    end

    # 現在ページに載る Row にだけ、代表 Song の event_id を1クエリで補完する。
    def attach_representative_events!(collection)
      song_ids = collection.map(&:representative_song_id).compact.uniq
      return if song_ids.empty?

      event_id_by_song = Song.where(id: song_ids).pluck(:id, :event_id).to_h
      collection.each do |row|
        row.representative_event_id = event_id_by_song[row.representative_song_id]
      end
    end

    def music_domain_id
      return @music_domain_id if defined?(@music_domain_id)

      @music_domain_id = Domain.find_by(name: "music")&.id
    end
  end
end
