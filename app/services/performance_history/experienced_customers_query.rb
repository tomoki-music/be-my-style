module PerformanceHistory
  # イベント詳細の楽曲パート募集欄に表示する「演奏経験のある人」を取得するクエリオブジェクト。
  #
  # 正データはSongPerformanceのような専用テーブルではなく、終了済みイベントに現存する
  # JoinPartCustomerそのもの(要件: 「イベント終了時点で残っているエントリーを演奏実績とする」)。
  # 確定操作は不要で、イベントが終了して画面を再読み込みすれば自動的に反映される。
  # エントリー取消(JoinPartCustomer物理削除)済みの分は、そもそもクエリ対象に上がらないため
  # 自然に除外される。
  #
  # 曲数xパート数分のN+1を避けるため、イベント単位でSQL2回(対象行のpluck + Customer一括取得)
  # に集約する。
  class ExperiencedCustomersQuery
    def self.call(event, now: Time.current)
      new(event, now: now).call
    end

    def initialize(event, now: Time.current)
      @event = event
      @now = now
    end

    # 戻り値: { [song_master_id, part_name] => [Customer, ...] } のHash
    def call
      song_master_ids = @event.songs.map(&:song_master_id).compact.uniq
      return Hash.new([].freeze) if song_master_ids.empty?

      rows = JoinPartCustomer
        .joins(join_part: { song: :event })
        .joins(:customer)
        .where(customers: { is_deleted: false })
        .where(songs: { song_master_id: song_master_ids })
        .where.not(events: { id: @event.id })
        .where("events.event_end_time <= ?", @now)
        .distinct
        .pluck("songs.song_master_id", "join_parts.join_part_name", "join_part_customers.customer_id")
      return Hash.new([].freeze) if rows.empty?

      grouped = Hash.new { |hash, key| hash[key] = Set.new }
      rows.each do |song_master_id, raw_part_name, customer_id|
        part_name = PartNameNormalizer.normalize(raw_part_name)
        next if part_name.blank?

        grouped[[song_master_id, part_name]] << customer_id
      end
      return Hash.new([].freeze) if grouped.empty?

      customer_ids = grouped.values.flat_map(&:to_a).uniq
      customers_by_id = Customer.where(id: customer_ids).index_by(&:id)

      grouped.transform_values { |ids| ids.filter_map { |id| customers_by_id[id] } }
    end
  end
end
