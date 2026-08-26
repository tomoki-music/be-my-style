class SongPerformance < ApplicationRecord
  belongs_to :customer
  belongs_to :song_master
  belongs_to :song, optional: true
  belongs_to :event, optional: true
  belongs_to :join_part, optional: true

  # Song/Event/JoinPart削除後も履歴自体は残すため、DB上はnullableにしている。
  # 新規作成時は必ずeventを伴う「イベント演奏実績」として扱うため、ここで必須化する。
  validates :event, presence: true, on: :create
  validates :song, presence: true, on: :create
  validates :part_name, presence: true, inclusion: { in: JoinPart::NAME_OPTIONS }
  validates :customer_id, uniqueness: {
    scope: [:song_master_id, :part_name, :event_id],
    message: "は既にこの曲・パートで演奏実績が登録されています"
  }

  scope :for_song_master_and_part, ->(song_master_id, part_name) { where(song_master_id: song_master_id, part_name: part_name) }
end
