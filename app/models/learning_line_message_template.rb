class LearningLineMessageTemplate < ApplicationRecord
  CATEGORIES = %w[followup assignment event beginner custom].freeze

  belongs_to :customer

  validates :title, presence: true, length: { maximum: 100 }
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :body, presence: true, length: { maximum: 500 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(active: :desc, category: :asc, title: :asc) }

  def category_label
    self.class.category_label(category)
  end

  def self.category_options
    CATEGORIES.map { |category| [category_label(category), category] }
  end

  def self.category_label(category)
    {
      "followup" => "要フォロー",
      "assignment" => "未提出",
      "event" => "ライブ前",
      "beginner" => "初心者向け",
      "custom" => "自由"
    }.fetch(category.to_s, category.to_s)
  end
end
