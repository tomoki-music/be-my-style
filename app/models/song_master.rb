class SongMaster < ApplicationRecord
  has_many :songs, dependent: :nullify
  has_many :song_performances, dependent: :restrict_with_exception
  has_many :customer_song_parts, dependent: :restrict_with_exception

  validates :normalized_song_name, presence: true
  # 自由入力(プロフィール編集の演奏可能曲登録)経由でも作成されるため、DBカラム上限
  # (varchar(255)、db/schema.rb参照)を超える入力をアプリ側で弾く。
  validates :song_name, presence: true, length: { maximum: 255 }
  validates :artist_name, length: { maximum: 255 }, allow_blank: true
end
