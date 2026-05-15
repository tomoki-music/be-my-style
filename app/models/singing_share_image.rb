class SingingShareImage < ApplicationRecord
  CAPTURE_TARGETS = %w[
    yearly-growth
    daily-challenge
    diagnosis-result
    ranking
    monthly-report
  ].freeze

  belongs_to :customer
  has_one_attached :image, dependent: :purge_later

  enum status: {
    pending: 0,
    completed: 1,
    failed: 2,
    expired: 3
  }

  validates :capture_target, presence: true, inclusion: { in: CAPTURE_TARGETS }
  validates :expires_at, presence: true
  validates :status, presence: true
  validate :completed_image_attached

  before_validation :set_default_expires_at, on: :create

  scope :expired_for_cleanup, -> { where("expires_at <= ?", Time.current) }

  def expired_for_public?
    expires_at.present? && expires_at <= Time.current
  end

  def public_title
    metadata.to_h["title"].presence || "BeMyStyle Singing シェア画像"
  end

  def public_description
    metadata.to_h["share_text"].presence || "#BeMyStyleSinging"
  end

  private

  def set_default_expires_at
    self.expires_at ||= 7.days.from_now
  end

  def completed_image_attached
    return unless completed?
    return if image.attached?

    errors.add(:image, "must be attached when completed")
  end
end
