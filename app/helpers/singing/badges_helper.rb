module Singing
  module BadgesHelper
    NEW_BADGE_THRESHOLD = 7.days

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
  end
end
