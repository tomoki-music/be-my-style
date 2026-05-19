class SingingGeneratedRecapMovie < ApplicationRecord
  belongs_to :customer
  has_one_attached :video_file, dependent: :purge_later

  enum status: {
    pending:    "pending",
    processing: "processing",
    completed:  "completed",
    failed:     "failed",
    expired:    "expired"
  }

  validates :year,   presence: true,
                     numericality: { only_integer: true, greater_than: 2000, less_than_or_equal_to: 2100 }
  validates :status, presence: true
  validates :customer_id, uniqueness: { scope: :year, message: "はすでにこの年の Recap Movie を持っています" }

  scope :reusable,        -> { completed.where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired_targets, -> { where(status: %w[pending processing completed failed]).where("expires_at < ?", Time.current) }

  def completed? = status == "completed"
  def failed?    = status == "failed"
  def expired?   = status == "expired"

  def expire!
    if completed?
      video_file.purge_later if video_file.attached?
      update!(status: :expired, error_message: nil)
    else
      update!(status: :expired)
    end
  end

  def reusable?
    completed? && (expires_at.nil? || expires_at > Time.current)
  end

  def mark_processing!
    update!(status: :processing)
  end

  def mark_completed!(generated_time: Time.current)
    update!(status: :completed, generated_at: generated_time)
  end

  def mark_failed!(message)
    update!(status: :failed, error_message: message)
  end
end
