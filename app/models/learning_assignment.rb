class LearningAssignment < ApplicationRecord
  STATUSES = %w[pending in_progress pending_review needs_revision completed].freeze
  OPEN_STATUSES = %w[pending in_progress].freeze
  ACTION_REQUIRED_STATUSES = (OPEN_STATUSES + %w[needs_revision]).freeze
  INCOMPLETE_STATUSES = (ACTION_REQUIRED_STATUSES + %w[pending_review]).freeze

  belongs_to :customer
  belongs_to :learning_student
  belongs_to :learning_student_training, optional: true
  belongs_to :reviewed_by, class_name: "Customer", optional: true

  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 1000 }, allow_blank: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :assignment_group_key, length: { maximum: 64 }, allow_blank: true
  validates :reaction_message, length: { maximum: 255 }, allow_blank: true
  validates :review_comment, length: { maximum: 1000 }, allow_blank: true
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
      "pending_review" => "先生確認待ち",
      "needs_revision" => "もう一度チャレンジ",
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
    due_on.present? && due_on < reference_date && ACTION_REQUIRED_STATUSES.include?(status)
  end

  def open?
    OPEN_STATUSES.include?(status)
  end

  def incomplete?
    INCOMPLETE_STATUSES.include?(status)
  end

  def action_required?
    ACTION_REQUIRED_STATUSES.include?(status)
  end

  def complete!(time: Time.current)
    update!(status: "completed", completed_at: time)
  end

  def training_assignment?
    learning_student_training_id.present?
  end

  def teacher_review_required?
    learning_student_training&.teacher_judged? || false
  end

  def mark_submitted_for_review!(message: nil, time: Time.current)
    update!(
      status: "pending_review",
      submitted_at: time,
      reaction_message: message.to_s.presence&.truncate(255)
    )
  end

  def approve_review!(reviewer:, comment: nil, time: Time.current)
    unless pending_review?
      errors.add(:status, "は先生確認待ちの課題だけ承認できます")
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      update!(
        status: "completed",
        completed_at: time,
        reviewed_at: time,
        reviewed_by: reviewer,
        review_comment: comment.to_s.presence
      )
      create_progress_log_from_review!
    end
  end

  def request_revision!(reviewer:, comment: nil, time: Time.current)
    unless pending_review?
      errors.add(:status, "は先生確認待ちの課題だけ差し戻しできます")
      raise ActiveRecord::RecordInvalid, self
    end

    update!(
      status: "needs_revision",
      reviewed_at: time,
      reviewed_by: reviewer,
      review_comment: comment.to_s.presence
    )
  end

  def pending_review?
    status == "pending_review"
  end

  def needs_revision?
    status == "needs_revision"
  end

  private

  def create_progress_log_from_review!
    training = learning_student_training
    learning_student.learning_progress_logs.create!(
      customer: customer,
      learning_student_training: training,
      part: training&.part || learning_student.main_part,
      training_title: training&.title || title,
      practiced_on: (submitted_at || Time.current).to_date,
      achievement_mark: "triangle",
      comment: progress_log_review_comment
    )
  end

  def progress_log_review_comment
    parts = ["先生確認で完了"]
    parts << "提出メッセージ: #{reaction_message}" if reaction_message.present?
    parts << "先生コメント: #{review_comment}" if review_comment.present?
    parts.join(" / ")
  end

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
