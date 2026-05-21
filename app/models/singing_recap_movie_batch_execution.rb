class SingingRecapMovieBatchExecution < ApplicationRecord
  belongs_to :admin, optional: true

  enum status: {
    enqueued:  "enqueued",
    running:   "running",
    completed: "completed",
    failed:    "failed",
    cancelled: "cancelled",
  }

  validates :year,   presence: true,
                     numericality: { only_integer: true, greater_than: 2000, less_than_or_equal_to: 2100 }
  validates :status, presence: true

  scope :active_for_year, ->(year) {
    where(year: year, status: %w[enqueued running])
  }

  def active?
    status.in?(%w[enqueued running])
  end

  def skipped_breakdown_hash
    skipped_breakdown.presence || {}
  end
end
