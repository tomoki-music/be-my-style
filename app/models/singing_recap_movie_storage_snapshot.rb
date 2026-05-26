class SingingRecapMovieStorageSnapshot < ApplicationRecord
  validates :snapshot_date, presence: true, uniqueness: true
  validates :attached_movie_count, numericality: { greater_than_or_equal_to: 0 }
  validates :total_bytes, numericality: { greater_than_or_equal_to: 0 }

  scope :recent,    -> (days) { where(snapshot_date: days.days.ago.to_date..) }
  scope :ordered,   -> { order(snapshot_date: :desc) }
  scope :ascending, -> { order(snapshot_date: :asc) }

  def total_gb
    total_bytes.to_f / Singing::RecapMovieStorageMetricsService::BYTES_PER_GB
  end
end
