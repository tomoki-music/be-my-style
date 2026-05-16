module Singing
  module BadgesHelper
    NEW_BADGE_THRESHOLD = 7.days

    SEASONAL_RANGES = {
      "season--spring" => (3..5),
      "season--summer" => (6..8),
      "season--autumn" => (9..11)
    }.freeze

    NEAR_COMPLETION_CTA = {
      streak:    "明日も診断する →",
      score:     "スコアに挑む →",
      milestone: "診断を続ける →",
      growth:    "成長を続ける →"
    }.freeze

    def singing_badge_label(badge)
      badge.label
    end

    def singing_badge_emoji(badge)
      badge.emoji
    end

    def singing_badge_display_text(badge)
      badge.display_text
    end

    def singing_badge_season_name(badge)
      badge.singing_ranking_season&.name
    end

    def singing_badge_new?(badge)
      badge.awarded_at >= NEW_BADGE_THRESHOLD.ago
    end

    def achievement_seasonal_class
      month = Date.today.month
      SEASONAL_RANGES.find { |_, range| range.include?(month) }&.first || "season--winter"
    end

    def near_completion_cta_label(badge_key)
      defn = SingingAchievementBadge::BADGE_DEFINITIONS[badge_key.to_s] || {}
      NEAR_COMPLETION_CTA[defn[:category]] || "診断する →"
    end

    def badge_earned_relative_time(earned_at)
      days_ago = ((Time.current - earned_at) / 1.day).to_i
      return "今日" if days_ago.zero?
      return "#{days_ago}日前" if days_ago < 7

      earned_at.strftime("%-m月%-d日")
    end
  end
end
