module Singing
  class YearlyAchievementRewindBuilder
    RARITY_RANK = Singing::MonthlyAchievementWrappedBuilder::RARITY_RANK

    Result = Struct.new(
      :year,
      :total_count,
      :rarity_counts,
      :has_legendary,
      :has_epic,
      :representative_badge,
      :monthly_highlights,
      :first_earned,
      :last_earned,
      :milestone_count,
      :items,
      :empty,
      keyword_init: true
    ) do
      def empty? = empty
    end

    def self.call(customer, year:)
      new(customer, year: year).build
    end

    def initialize(customer, year:)
      @customer = customer
      @year     = year.to_i
    end

    def build
      return empty_result unless @customer

      all_badges = @customer.singing_achievement_badges
                            .includes(:singing_diagnosis)
                            .order(:earned_at)
                            .to_a
                            .select { |b| b.earned_at.year == @year }

      return empty_result if all_badges.empty?

      items = all_badges.map { |b| build_item(b) }

      rarity_counts = SingingAchievementBadge::RARITY_ORDER.each_with_object({}) do |rarity, h|
        h[rarity] = items.count { |i| i.rarity == rarity }
      end

      monthly_highlights = build_monthly_highlights(all_badges)

      Result.new(
        year:                @year,
        total_count:         items.size,
        rarity_counts:       rarity_counts,
        has_legendary:       rarity_counts[:legendary] > 0,
        has_epic:            rarity_counts[:epic] > 0,
        representative_badge: representative(items),
        monthly_highlights:  monthly_highlights,
        first_earned:        items.min_by(&:earned_at),
        last_earned:         items.max_by(&:earned_at),
        milestone_count:     rarity_counts[:legendary] + rarity_counts[:epic],
        items:               items,
        empty:               false
      )
    end

    private

    def build_item(badge)
      defn = SingingAchievementBadge::BADGE_DEFINITIONS[badge.badge_key.to_s] || {}
      Singing::AchievementTimelineBuilder::TimelineItem.new(
        customer_achievement_badge: badge,
        badge_key:  badge.badge_key,
        definition: defn
      )
    end

    def representative(items)
      pinned = items.find(&:pinned?)
      return pinned if pinned

      items.min_by { |i| [RARITY_RANK[i.rarity] || 99, i.earned_at] }
    end

    def build_monthly_highlights(all_badges)
      months_with_badges = all_badges
        .group_by { |b| b.earned_at.beginning_of_month }
        .sort_by { |month, _| month }

      months_with_badges.map do |month, badges|
        Singing::MonthlyAchievementWrappedBuilder.build_from_badges(
          badges: badges,
          month:  month
        )
      end
    end

    def empty_result
      Result.new(
        year:                @year,
        total_count:         0,
        rarity_counts:       SingingAchievementBadge::RARITY_ORDER.each_with_object({}) { |r, h| h[r] = 0 },
        has_legendary:       false,
        has_epic:            false,
        representative_badge: nil,
        monthly_highlights:  [],
        first_earned:        nil,
        last_earned:         nil,
        milestone_count:     0,
        items:               [],
        empty:               true
      )
    end
  end
end
