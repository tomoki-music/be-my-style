module PerformanceHistory
  # プロフィール画面の「演奏実績」表示用に、customerの終了済みイベントにおけるJoinPartCustomerを
  # 曲(SongMaster) x パート単位で集約する。
  #
  # 正データはSongPerformanceのような専用テーブルではなく、終了済みイベントに現存する
  # JoinPartCustomerそのもの。開催前イベントのエントリーは対象外(SQL側でevent_end_time <= now
  # に絞り込む)。song_master_idが未解決のSong(rake song_masters:backfill_songs未実行の
  # 旧データ)は、名寄せ不能のため対象外になる。
  #
  # 全イベントをロードしてRuby側だけで絞り込むことはせず、終了済み・song_master解決済みという
  # 条件をSQL側で先に絞り込んだうえで、includesで関連を一括取得しRuby側で集計する。
  class ProfileQuery
    Summary = Struct.new(
      :song_master,
      :part_name,
      :count,
      :latest_performed_on,
      :entries,
      keyword_init: true
    )
    Entry = Struct.new(:event, :performed_on, keyword_init: true)

    def self.call(customer, now: Time.current)
      new(customer, now: now).call
    end

    def initialize(customer, now: Time.current)
      @customer = customer
      @now = now
    end

    def call
      join_part_customers = @customer.join_part_customers
        .joins(join_part: { song: :event })
        .where("events.event_end_time <= ?", @now)
        .where.not(songs: { song_master_id: nil })
        .includes(join_part: { song: [:song_master, :event] })
        .order("events.event_start_time DESC")

      # (event_id, song_master_id, part_name)で重複排除する。同一Songに同名JoinPartが
      # 複数存在するようなデータ不整合があっても、同一イベント・同一曲・同一パートを
      # 二重計上しないための防御。
      seen = Set.new
      rows = join_part_customers.filter_map do |join_part_customer|
        song = join_part_customer.join_part.song
        event = song.event
        part_name = PartNameNormalizer.normalize(join_part_customer.join_part.join_part_name)
        next if part_name.blank?

        dedupe_key = [event.id, song.song_master_id, part_name]
        next if seen.include?(dedupe_key)
        seen << dedupe_key

        { song_master: song.song_master, part_name: part_name, event: event, performed_on: event.event_start_time&.to_date }
      end

      rows
        .group_by { |row| [row[:song_master].id, row[:part_name]] }
        .map do |_key, group|
          entries = group
            .sort_by { |row| row[:performed_on] || Date.new(0) }
            .reverse
            .map { |row| Entry.new(event: row[:event], performed_on: row[:performed_on]) }

          Summary.new(
            song_master: group.first[:song_master],
            part_name: group.first[:part_name],
            count: group.size,
            latest_performed_on: group.filter_map { |row| row[:performed_on] }.max,
            entries: entries
          )
        end
        .sort_by { |summary| summary.latest_performed_on || Date.new(0) }
        .reverse
    end
  end
end
