class LearningTrainingMaster < ApplicationRecord
  belongs_to :customer
  has_many :learning_student_trainings, dependent: :nullify
  has_many :learning_band_trainings, dependent: :nullify

  validates :part, presence: true, inclusion: { in: LearningCatalog::PARTS.keys }
  validates :period, presence: true, inclusion: { in: LearningCatalog::PERIODS }
  validates :level, presence: true, inclusion: { in: LearningCatalog::LEVELS }
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, presence: true
  validates :achievement_criteria, length: { maximum: 500 }
  validates :frequency, length: { maximum: 100 }

  scope :ordered, -> { order(:part, :period, :level, :title) }
  scope :band_training, -> { where(is_band_training: true) }
  scope :individual_training, -> { where(is_band_training: false) }
  scope :with_filters, lambda { |params|
    scope = all
    scope = scope.where(part: params[:part]) if params[:part].present?
    scope = scope.where(period: params[:period]) if params[:period].present?
    scope = scope.where(level: params[:level]) if params[:level].present?
    scope = scope.where(is_band_training: ActiveModel::Type::Boolean.new.cast(params[:band])) if params[:band].present?
    if params[:keyword].present?
      keyword = "%#{sanitize_sql_like(params[:keyword])}%"
      scope = scope.where("learning_training_masters.title LIKE ? OR learning_training_masters.description LIKE ?", keyword, keyword)
    end
    scope
  }

  def kind_label
    is_band_training? ? "バンド練習" : "個人"
  end
end
