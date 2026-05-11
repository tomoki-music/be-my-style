class LearningAssignment < ApplicationRecord
  STATUSES = %w[pending in_progress completed].freeze
  OPEN_STATUSES = %w[pending in_progress].freeze

  belongs_to :customer
  belongs_to :learning_student
  belongs_to :learning_student_training, optional: true

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }, allow_blank: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :assignment_group_key, length: { maximum: 64 }, allow_blank: true
  validate :student_belongs_to_customer
  validate :student_training_belongs_to_student

  scope :active, -> { where(status: OPEN_STATUSES) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :completed_recent_first, -> { where(status: "completed").order(completed_at: :desc, updated_at: :desc) }
  scope :overdue, -> { active.where("due_on < ?", Date.current) }

  def self.status_label(status)
    {
      "pending" => "未着手",
      "in_progress" => "進行中",
      "completed" => "完了"
    }.fetch(status.to_s, status.to_s)
  end

  def status_label
    self.class.status_label(status)
  end

  def grouping_key
    assignment_group_key.presence || "assignment-#{id}"
  end

  def overdue?(reference_date = Date.current)
    due_on.present? && due_on < reference_date && status != "completed"
  end

  def open?
    OPEN_STATUSES.include?(status)
  end

  def complete!(time: Time.current)
    update!(status: "completed", completed_at: time)
  end

  def training_assignment?
    learning_student_training_id.present?
  end

  private

  def student_belongs_to_customer
    return if customer_id.blank? || learning_student.blank?
    return if learning_student.customer_id == customer_id

    errors.add(:learning_student, "は同じ顧問の生徒を選択してください")
  end

  def student_training_belongs_to_student
    return if learning_student_training.blank?
    return if learning_student_training.customer_id == customer_id &&
              learning_student_training.learning_student_id == learning_student_id

    errors.add(:learning_student_training, "は同じ顧問・生徒の割当を選択してください")
  end
end
