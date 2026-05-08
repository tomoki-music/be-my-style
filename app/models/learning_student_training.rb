class LearningStudentTraining < ApplicationRecord
  belongs_to :customer
  belongs_to :learning_student
  belongs_to :learning_training_master, optional: true
  has_many :learning_progress_logs, dependent: :nullify

  validates :part, presence: true, inclusion: { in: LearningCatalog::PARTS.keys }
  validates :period, presence: true, inclusion: { in: LearningCatalog::PERIODS }
  validates :level, presence: true, inclusion: { in: LearningCatalog::LEVELS }
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, presence: true
  validates :status, presence: true, inclusion: { in: LearningCatalog::TRAINING_STATUSES.keys }
  validates :achievement_mark, presence: true, inclusion: { in: LearningCatalog::ACHIEVEMENT_MARKS.keys }

  before_validation :copy_master_fields, if: -> { learning_training_master.present? && title.blank? }
  before_validation :set_default_position, on: :create
  after_update :award_achievement_point, if: :saved_change_to_status?

  scope :ordered, -> { order(:position, :created_at) }
  scope :with_filters, lambda { |params|
    scope = all
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where(part: params[:part]) if params[:part].present?
    scope = scope.where(level: params[:level]) if params[:level].present?
    if params[:keyword].present?
      keyword = "%#{sanitize_sql_like(params[:keyword])}%"
      scope = scope.where("learning_student_trainings.title LIKE ? OR learning_student_trainings.description LIKE ?", keyword, keyword)
    end
    scope
  }

  def star?
    achievement_mark == "star"
  end

  private

  def copy_master_fields
    self.part = learning_training_master.part
    self.period = learning_training_master.period
    self.level = learning_training_master.level
    self.title = learning_training_master.title
    self.description = learning_training_master.description
    self.achievement_criteria = learning_training_master.achievement_criteria
    self.frequency = learning_training_master.frequency
  end

  def set_default_position
    return if position.to_i.positive?

    max_position = learning_student&.learning_student_trainings&.maximum(:position).to_i
    self.position = max_position + 1
  end

  def award_achievement_point
    return unless status == "achieved"

    # 同じ課題での二重付与防止
    already_awarded = LearningEffortPoint.exists?(
      learning_student_id: learning_student_id,
      point_type: "training_achieved",
      description: "課題達成: #{title}"
    )
    return if already_awarded

    LearningEffortPoint.create!(
      customer_id: customer_id,
      learning_student_id: learning_student_id,
      point_type: "training_achieved",
      points: LearningEffortPoint::POINT_TYPES["training_achieved"][:points],
      description: "課題達成: #{title}",
      earned_on: Date.current
    )
    learning_student.increment!(:total_effort_points,
                                LearningEffortPoint::POINT_TYPES["training_achieved"][:points])
  end
end
