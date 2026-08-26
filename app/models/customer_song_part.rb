class CustomerSongPart < ApplicationRecord
  belongs_to :customer
  belongs_to :song_master
  belongs_to :song, optional: true

  # Song削除後も自己申告自体は残すため、DB上song_idはnullableだが新規登録時は必須にする
  # (登録画面は必ず既存Songを選ぶ方式のため)。
  validates :song, presence: true, on: :create
  validates :part_name, presence: true, inclusion: { in: JoinPart::NAME_OPTIONS }
  validates :customer_id, uniqueness: {
    scope: [:song_master_id, :part_name],
    message: "は既に演奏可能曲として登録されています"
  }
end
