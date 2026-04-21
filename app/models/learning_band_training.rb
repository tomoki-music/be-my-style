class LearningBandTraining < ApplicationRecord
  belongs_to :customer
  belongs_to :learning_band
  belongs_to :learning_training_master, optional: true

  validates :part, presence: true, inclusion: { in: LearningCatalog::PARTS.keys }
  validates :period, presence: true, inclusion: { in: LearningCatalog::PERIODS }
  validates :level, presence: true, inclusion: { in: LearningCatalog::LEVELS }
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, presence: true
  validates :status, presence: true, inclusion: { in: LearningCatalog::TRAINING_STATUSES.keys }
  validates :achievement_mark, presence: true, inclusion: { in: LearningCatalog::ACHIEVEMENT_MARKS.keys }

  before_validation :copy_master_fields, if: -> { learning_training_master.present? && title.blank? }
  before_validation :set_default_position, on: :create
  before_validation :normalize_related_parts

  scope :ordered, -> { order(:position, :created_at) }

  def star?
    achievement_mark == "star"
  end

  def related_parts_list
    related_parts.to_s.split(",").map(&:strip).reject(&:blank?).uniq
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

    max_position = learning_band&.learning_band_trainings&.maximum(:position).to_i
    self.position = max_position + 1
  end

  def normalize_related_parts
    self.related_parts = related_parts_list.join(",")
  end
end
