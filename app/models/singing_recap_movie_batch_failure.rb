class SingingRecapMovieBatchFailure < ApplicationRecord
  belongs_to :singing_recap_movie_batch_execution
  belongs_to :customer
  belongs_to :recap_movie, class_name: "SingingGeneratedRecapMovie",
             foreign_key: :recap_movie_id, optional: true

  validates :year,        presence: true, numericality: { only_integer: true }
  validates :error_class, presence: true
  validates :failed_at,   presence: true
end
