class SingingSeasonRankingEntry < ApplicationRecord
  belongs_to :singing_ranking_season
  belongs_to :customer
  belongs_to :singing_diagnosis, optional: true

  CATEGORIES = %w[overall pitch rhythm expression growth].freeze

  validates :singing_ranking_season, presence: true
  validates :customer, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :score, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rank, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :customer_id, uniqueness: { scope: [:singing_ranking_season_id, :category],
                                        message: "はこのシーズン・カテゴリに既にエントリーされています" }

  scope :by_rank, -> { order(rank: :asc) }
  scope :overall, -> { where(category: "overall") }
  scope :for_category, ->(cat) { where(category: cat) }
end
