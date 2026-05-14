class SingingDailyChallenge < ApplicationRecord
  CHALLENGE_TYPES = %w[score_threshold count].freeze
  TARGET_ATTRIBUTES = %w[overall pitch rhythm expression].freeze

  has_many :singing_daily_challenge_progresses, dependent: :destroy

  validates :challenge_date, presence: true, uniqueness: true
  validates :challenge_type, presence: true, inclusion: { in: CHALLENGE_TYPES }
  validates :target_attribute, presence: true, inclusion: { in: TARGET_ATTRIBUTES }
  validates :threshold_value, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :xp_reward, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :title, presence: true
  validates :description, presence: true

  scope :for_date, ->(date) { find_by(challenge_date: date) }

  TARGET_ATTRIBUTE_LABELS = {
    "overall"    => "総合スコア",
    "pitch"      => "ピッチ",
    "rhythm"     => "リズム",
    "expression" => "表現力"
  }.freeze

  TARGET_ATTRIBUTE_ICONS = {
    "overall"    => "🎯",
    "pitch"      => "🎵",
    "rhythm"     => "🥁",
    "expression" => "✨"
  }.freeze

  def target_label
    TARGET_ATTRIBUTE_LABELS.fetch(target_attribute, target_attribute)
  end

  def target_icon
    TARGET_ATTRIBUTE_ICONS.fetch(target_attribute, "🎯")
  end

  def score_column
    "#{target_attribute}_score"
  end

  def completed_by?(customer)
    singing_daily_challenge_progresses.exists?(customer: customer, singing_daily_challenge: self)
  end

  def progress_for(customer)
    singing_daily_challenge_progresses.find_by(customer: customer)
  end
end
