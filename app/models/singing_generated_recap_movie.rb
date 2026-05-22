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
  scope :cleanup_pending, -> { expired_targets }
  scope :recently_cleaned, ->(since = 7.days.ago) { expired.where("cleaned_up_at >= ?", since) }

  def completed?  = status == "completed"
  def failed?     = status == "failed"
  def expired?    = status == "expired"
  def cleaned_up? = cleaned_up_at.present?

  def expire!
    if completed?
      video_file.purge_later if video_file.attached?
      update!(status: :expired, error_message: nil, cleaned_up_at: Time.current)
    else
      update!(status: :expired, cleaned_up_at: Time.current)
    end
  end

  def reusable?
    completed? && (expires_at.nil? || expires_at > Time.current)
  end

  def generated_props_hash
    generated_props.presence || {}
  end

  def mark_processing!
    update!(status: :processing)
  end

  def mark_completed!(generated_time: Time.current)
    new_expires_at = Singing::RecapMovieExpiryPolicy.expires_at_for(customer)
    update!(status: :completed, generated_at: generated_time, expires_at: new_expires_at)
  end

  def mark_failed!(message)
    update!(status: :failed, error_message: message)
  end
end
