module SongPerformances
  # イベント詳細の楽曲パート募集欄に表示する「演奏経験のある人」を、曲数xパート数分の
  # N+1を発生させずに一括取得するクエリオブジェクト。
  #
  # 対象は確定済みの演奏実績(SongPerformance、= イベント終了後に「実績を確定」または
  # バックフィルで登録された分)のみ。自己申告の演奏可能曲(CustomerSongPart)は含めない
  # (要件のとおり、経験者欄は「演奏経験のある人」に絞り、自己申告はプロフィール内表示に限定する)。
  #
  # 「現在閲覧中のイベント自身」のエントリーは、まだ終了・確定していない限りSongPerformanceに
  # 存在しないため自然に除外されるが、閲覧中イベントが終了済みで自分自身の実績も確定済みの場合に
  # 備え、event_idで明示的に除外する。
  class ExperiencedCustomersByEventQuery
    def self.call(event)
      new(event).call
    end

    def initialize(event)
      @event = event
    end

    # 戻り値: { [song_master_id, part_name] => [Customer, ...] } のHash
    def call
      song_master_ids = @event.songs.map(&:song_master_id).compact.uniq
      return Hash.new([].freeze) if song_master_ids.empty?

      tuples = SongPerformance
        .where(song_master_id: song_master_ids)
        .where.not(event_id: @event.id)
        .distinct
        .pluck(:song_master_id, :part_name, :customer_id)
      return Hash.new([].freeze) if tuples.empty?

      customer_ids = tuples.map { |(_song_master_id, _part_name, customer_id)| customer_id }.uniq
      customers_by_id = Customer.active.where(id: customer_ids).index_by(&:id)

      grouped = Hash.new { |hash, key| hash[key] = [] }
      tuples.each do |song_master_id, part_name, customer_id|
        customer = customers_by_id[customer_id]
        next if customer.blank?

        grouped[[song_master_id, part_name]] << customer
      end
      grouped
    end
  end
end
