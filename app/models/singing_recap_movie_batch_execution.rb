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

  def result_summary_available?
    actual_created_movies_count > 0 ||
      actual_regenerated_movies_count > 0 ||
      actual_skipped_movies_count > 0
  end

  def enqueue_success_rate
    total = actual_created_movies_count + actual_regenerated_movies_count + failed_movies_count
    return nil if total.zero?

    success = actual_created_movies_count + actual_regenerated_movies_count
    (success.to_f / total * 100).round(1)
  end

  def skipped_breakdown_hash
    skipped_breakdown.presence || {}
  end

  def progress_percent
    return 0 if total_movies_count.zero?

    processed = completed_movies_count + failed_movies_count
    [(processed.to_f / total_movies_count * 100).round, 100].min
  end

  def remaining_movies_count
    return 0 if total_movies_count.zero?

    [total_movies_count - completed_movies_count - failed_movies_count, 0].max
  end

  def duration_seconds
    base = finished_at || Time.current
    return nil unless started_at

    (base - started_at).to_i
  end
end
