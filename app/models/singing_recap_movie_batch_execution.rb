class SingingRecapMovieBatchExecution < ApplicationRecord
  belongs_to :admin, optional: true

  enum status: { enqueued: "enqueued" }

  validates :year,   presence: true,
                     numericality: { only_integer: true, greater_than: 2000, less_than_or_equal_to: 2100 }
  validates :status, presence: true

  def skipped_breakdown_hash
    skipped_breakdown.presence || {}
  end
end
