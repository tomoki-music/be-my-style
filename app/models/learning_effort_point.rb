class LearningEffortPoint < ApplicationRecord
  POINT_TYPES = {
    "progress_log"      => { points: 5,  label: "練習記録" },
    "training_achieved" => { points: 20, label: "課題達成" },
    "streak_bonus"      => { points: 10, label: "継続ボーナス" },
    "manual"            => { points: 0,  label: "手動付与" }
  }.freeze

  belongs_to :customer
  belongs_to :learning_student

  validates :point_type, presence: true, inclusion: { in: POINT_TYPES.keys }
  validates :points, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :earned_on, presence: true

  scope :this_month, -> { where(earned_on: Date.current.beginning_of_month..) }
  scope :this_week,  -> { where(earned_on: Date.current.beginning_of_week..) }
  scope :recent_first, -> { order(earned_on: :desc, created_at: :desc) }
end
