class LearningSchoolApplication < ApplicationRecord
  STATUSES = %w[pending contacted adopted rejected].freeze

  validates :school_name,  presence: true, length: { maximum: 100 }
  validates :advisor_name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "はメールアドレス形式で入力してください" }
  validates :student_count, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :message, length: { maximum: 1000 }
  validates :status, inclusion: { in: STATUSES }

  scope :pending,  -> { where(status: "pending") }
  scope :recent,   -> { order(created_at: :desc) }
end
