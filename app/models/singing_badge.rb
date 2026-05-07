class SingingBadge < ApplicationRecord
  belongs_to :customer
  belongs_to :singing_ranking_season

  BADGE_TYPES = %w[
    season_1st
    season_2nd
    season_top3
    season_top10
    rapid_growth
    consecutive_participation
  ].freeze

  BADGE_LABELS = {
    "season_1st"               => "今月の王者",
    "season_2nd"               => "準優勝",
    "season_top3"              => "TOP3",
    "season_top10"             => "TOP10入り",
    "rapid_growth"             => "急成長シンガー",
    "consecutive_participation" => "継続の証"
  }.freeze

  BADGE_EMOJIS = {
    "season_1st"               => "🥇",
    "season_2nd"               => "🥈",
    "season_top3"              => "🥉",
    "season_top10"             => "🎯",
    "rapid_growth"             => "📈",
    "consecutive_participation" => "🔥"
  }.freeze

  validates :badge_type, presence: true, inclusion: { in: BADGE_TYPES }
  validates :awarded_at, presence: true
  validates :badge_type, uniqueness: { scope: [:customer_id, :singing_ranking_season_id] }

  def label
    BADGE_LABELS.fetch(badge_type, badge_type)
  end

  def emoji
    BADGE_EMOJIS[badge_type]
  end

  def display_text
    [emoji, label].compact.join(" ")
  end
end
