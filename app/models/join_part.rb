class JoinPart < ApplicationRecord
  # 募集パート名の候補一覧。以前は各Controller/Viewにハードコードされ重複していた
  # (events#new/events#copyでは"Other"が抜けているなど表記ゆれもあった)ため、
  # ここに一本化する。演奏実績(SongPerformance)・自己申告演奏可能曲(CustomerSongPart)の
  # part_nameも、新しい語彙を増やさずこの一覧を再利用する。
  NAME_OPTIONS = %w[Vocal Guitar Bass Drums Keyboard Other].freeze

  belongs_to :song
  has_many :join_part_customers, dependent: :destroy
  has_many :customers, through: :join_part_customers, dependent: :destroy
  # 演奏実績は、JoinPart削除後も履歴として残すためnullify(song_templates.source_song_idと同じ考え方)。
  has_many :song_performances, dependent: :nullify

  with_options presence: true do
    validates :join_part_name
  end

  # 一般・公開画面で「現役参加者」だけを扱う際に使う。
  # JoinPartCustomerレコード自体は削除しないため、ここでの絞り込みは表示専用。
  def active_customers
    customers.active
  end
end
