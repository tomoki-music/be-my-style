class LearningProgressLog < ApplicationRecord
  belongs_to :customer
  belongs_to :learning_student
  belongs_to :learning_student_training, optional: true

  validates :part, presence: true, inclusion: { in: LearningCatalog::PARTS.keys }
  validates :training_title, presence: true, length: { maximum: 100 }
  validates :practiced_on, presence: true
  validates :achievement_mark, presence: true, inclusion: { in: LearningCatalog::ACHIEVEMENT_MARKS.keys }
  validates :comment, length: { maximum: 1000 }

  before_validation :copy_training_fields, if: -> { learning_student_training.present? && training_title.blank? }

  scope :recent_first, -> { order(practiced_on: :desc, created_at: :desc) }
  scope :with_filters, lambda { |params|
    scope = all
    scope = scope.where(part: params[:part]) if params[:part].present?
    scope = scope.where(learning_student_id: params[:student_id]) if params[:student_id].present?
    if params[:keyword].present?
      keyword = "%#{sanitize_sql_like(params[:keyword])}%"
      scope = scope.where("learning_progress_logs.training_title LIKE ? OR learning_progress_logs.comment LIKE ?", keyword, keyword)
    end
    scope
  }

  def star?
    achievement_mark == "star"
  end

  private

  def copy_training_fields
    self.part = learning_student_training.part
    self.training_title = learning_student_training.title
  end
end
