class SingingRecapMovieBatchFailure < ApplicationRecord
  belongs_to :singing_recap_movie_batch_execution
  belongs_to :customer
  belongs_to :recap_movie, class_name: "SingingGeneratedRecapMovie",
             foreign_key: :recap_movie_id, optional: true
  belongs_to :retried_by, class_name: "Admin",
             foreign_key: :retried_by_id, optional: true

  validates :year,        presence: true, numericality: { only_integer: true }
  validates :error_class, presence: true
  validates :failed_at,   presence: true

  enum retry_status: {
    pending:      "pending",
    retried:      "retried",
    skipped:      "skipped",
    retry_failed: "retry_failed"
  }, _prefix: :retry

  scope :retryable, -> { where(retry_status: "pending") }

  def retryable?
    retry_pending?
  end

  def retry_status_badge_class
    case retry_status
    when "pending"      then "badge-secondary"
    when "retried"      then "badge-success"
    when "skipped"      then "badge-dark"
    when "retry_failed" then "badge-danger"
    end
  end

  def retry_status_label
    case retry_status
    when "pending"      then "Pending"
    when "retried"      then "Retried"
    when "skipped"      then "Skipped"
    when "retry_failed" then "Retry Failed"
    end
  end

  def retry_disabled_reason
    return nil if retryable?

    case retry_status
    when "retried"      then "Retry済み（#{retried_by&.name || '不明'}）"
    when "skipped"      then "Completed済みのためSkip"
    when "retry_failed" then "Retry失敗"
    end
  end
end
