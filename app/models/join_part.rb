class JoinPart < ApplicationRecord
  # 募集パート名の候補一覧。以前は各Controller/Viewにハードコードされ重複していた
  # (events#new/events#copyでは"Other"が抜けているなど表記ゆれもあった)ため、
  # ここに一本化する。演奏実績の動的集計(PerformanceHistory)・自己申告演奏可能曲
  # (CustomerSongPart)のpart_nameも、新しい語彙を増やさずこの一覧を再利用する。
  NAME_OPTIONS = %w[Vocal Guitar Bass Drums Keyboard Other].freeze

  belongs_to :song
  has_many :join_part_customers, dependent: :destroy
  has_many :customers, through: :join_part_customers, dependent: :destroy

  with_options presence: true do
    validates :join_part_name
  end

  # 一般・公開画面で「現役参加者」だけを扱う際に使う。
  # JoinPartCustomerレコード自体は削除しないため、ここでの絞り込みは表示専用。
  def active_customers
    customers.active
  end
end
