module Singing
  class NextBadgeHintAggregator
    Result = Struct.new(
      :badge_key,
      :progress_hint,
      :is_close,
      keyword_init: true
    )

    RARITY_WEIGHTS   = { legendary: 40, epic: 30, rare: 20, common: 10 }.freeze
    # streak系を優遇：連続性があり「あと◯日」が最もモチベーションになりやすい
    CATEGORY_WEIGHTS = { streak: 15, milestone: 10, score: 10, growth: 5, ranking: 5 }.freeze

    def self.call(customer, earned_badge_keys:)
      new(customer, earned_badge_keys: earned_badge_keys).call
    end

    def initialize(customer, earned_badge_keys:)
      @customer          = customer
      @earned_badge_keys = earned_badge_keys
    end

    def call
      hints = Singing::ProgressHintBuilder.call(
        @customer,
        earned_badge_keys: @earned_badge_keys
      )

      candidates = hints
        .select { |h| h.progress_ratio > 0 }
        .sort_by { |h| -priority_score(h) }

      best = candidates.first
      return nil unless best

      Result.new(
        badge_key:     best.badge_key,
        progress_hint: best,
        is_close:      best.progress_ratio >= 0.8
      )
    end

    private

    def priority_score(hint)
      defn            = SingingAchievementBadge::BADGE_DEFINITIONS[hint.badge_key] || {}
      rarity_weight   = RARITY_WEIGHTS[defn[:rarity]] || 0
      category_weight = CATEGORY_WEIGHTS[defn[:category]] || 0
      progress_weight = hint.progress_ratio * 30

      rarity_weight + category_weight + progress_weight
    end
  end
end
