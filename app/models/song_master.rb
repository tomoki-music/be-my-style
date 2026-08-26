class SongMaster < ApplicationRecord
  has_many :songs, dependent: :nullify
  has_many :song_performances, dependent: :restrict_with_exception
  has_many :customer_song_parts, dependent: :restrict_with_exception

  validates :normalized_song_name, presence: true
  validates :song_name, presence: true
end
