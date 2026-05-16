module Singing
  class MonthlyAchievementWrappedBuilder
    MONTH_LABELS = Singing::AchievementTimelineBuilder::MONTH_LABELS

    RARITY_RANK = { legendary: 0, epic: 1, rare: 2, common: 3 }.freeze

    Result = Struct.new(
      :month,
      :month_str,
      :month_label,
      :total_count,
      :rarity_counts,
      :has_legendary,
      :has_epic,
      :representative_badge,
      :first_earned,
      :last_earned,
      :items,
      :empty,
      keyword_init: true
    ) do
      def empty? = empty
    end

    def self.call(customer, month_str)
      new(customer, month_str).build
    end

    def initialize(customer, month_str)
      @customer  = customer
      @month_str = month_str.to_s
    end

    def build
      month = parse_month(@month_str)
      return empty_result(month) unless month

      badges = badges_for_month(month)
      return empty_result(month) if badges.empty?

      items = badges.map { |b| build_item(b) }

      rarity_counts = SingingAchievementBadge::RARITY_ORDER.each_with_object({}) do |rarity, h|
        h[rarity] = items.count { |i| i.rarity == rarity }
      end

      Result.new(
        month:               month,
        month_str:           @month_str,
        month_label:         MONTH_LABELS[month.month] || "挑戦を続けた月",
        total_count:         items.size,
        rarity_counts:       rarity_counts,
        has_legendary:       rarity_counts[:legendary] > 0,
        has_epic:            rarity_counts[:epic] > 0,
        representative_badge: representative(items),
        first_earned:        items.min_by(&:earned_at),
        last_earned:         items.max_by(&:earned_at),
        items:               items,
        empty:               false
      )
    end

    private

    def parse_month(str)
      Time.zone.parse("#{str}-01").beginning_of_month
    rescue ArgumentError, TypeError
      nil
    end

    def badges_for_month(month)
      range = month.beginning_of_month..month.end_of_month
      @customer.singing_achievement_badges
               .includes(:singing_diagnosis)
               .where(earned_at: range)
               .order(earned_at: :asc)
    end

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

    def empty_result(month)
      month_num = month&.month
      Result.new(
        month:               month,
        month_str:           @month_str,
        month_label:         month_num ? (MONTH_LABELS[month_num] || "挑戦を続けた月") : "",
        total_count:         0,
        rarity_counts:       SingingAchievementBadge::RARITY_ORDER.each_with_object({}) { |r, h| h[r] = 0 },
        has_legendary:       false,
        has_epic:            false,
        representative_badge: nil,
        first_earned:        nil,
        last_earned:         nil,
        items:               [],
        empty:               true
      )
    end
  end
end
