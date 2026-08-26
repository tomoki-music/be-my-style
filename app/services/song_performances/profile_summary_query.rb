module SongPerformances
  # プロフィール画面の「演奏実績」表示用に、customerの確定済みSongPerformanceを
  # 曲x パート単位で集約する。N+1回避のため、includesで関連を一括取得したうえで
  # Ruby側でgroup_byする(1customerあたりの演奏実績件数は小規模想定のため、
  # DBでのGROUP BYより「集計元イベント一覧」まで含めて扱いやすいこちらを採用)。
  class ProfileSummaryQuery
    Summary = Struct.new(
      :song_master,
      :part_name,
      :count,
      :latest_performed_on,
      :performances,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      performances = @customer.song_performances
        .includes(:song_master, :song, event: :community)
        .order(performed_on: :desc, created_at: :desc)

      performances
        .group_by { |performance| [performance.song_master_id, performance.part_name] }
        .map do |(_song_master_id, part_name), group|
          Summary.new(
            song_master: group.first.song_master,
            part_name: part_name,
            count: group.size,
            latest_performed_on: group.filter_map(&:performed_on).max,
            performances: group.sort_by { |performance| performance.performed_on || performance.created_at }.reverse
          )
        end
        .sort_by { |summary| summary.latest_performed_on || Date.new(0) }
        .reverse
    end
  end
end
