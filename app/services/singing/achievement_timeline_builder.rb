module Singing
  class AchievementTimelineBuilder
    MONTH_LABELS = {
      1  => "新しい年が始まった月",
      2  => "冬の寒さの中で挑んだ月",
      3  => "春の訪れとともに歌った月",
      4  => "桜のように咲き誇った月",
      5  => "挑戦が形になった月",
      6  => "雨の日も歌い続けた月",
      7  => "夏の熱気の中で磨いた月",
      8  => "情熱が最高潮に達した月",
      9  => "実りの季節に重ねた月",
      10 => "秋の深まりとともに積み上げた月",
      11 => "年末に向けて積み重ねた月",
      12 => "一年を締めくくった月"
    }.freeze

    TimelineItem = Struct.new(
      :customer_achievement_badge,
      :badge_key,
      :definition,
      keyword_init: true
    ) do
      def label    = definition[:label]    || badge_key
      def emoji    = definition[:emoji]    || "🎯"
      def rarity   = definition[:rarity]   || :common
      def category = definition[:category] || :milestone
      def earned_at = customer_achievement_badge.earned_at
      def pinned?  = customer_achievement_badge.pinned?
      def badge_id = customer_achievement_badge.id
    end

    TimelineMonthGroup = Struct.new(:month, :label, :items, keyword_init: true)

    def self.call(customer)
      new(customer).build
    end

    def initialize(customer)
      @customer = customer
    end

    def build
      badges = @customer.singing_achievement_badges
                        .includes(:singing_diagnosis)
                        .order(earned_at: :desc)

      badges
        .group_by { |b| b.earned_at.beginning_of_month }
        .map do |month, month_badges|
          TimelineMonthGroup.new(
            month: month,
            label: month_label(month),
            items: month_badges.map { |b| build_item(b) }
          )
        end
    end

    private

    def build_item(badge)
      defn = SingingAchievementBadge::BADGE_DEFINITIONS[badge.badge_key.to_s] || {}
      TimelineItem.new(
        customer_achievement_badge: badge,
        badge_key:  badge.badge_key,
        definition: defn
      )
    end

    def month_label(month)
      MONTH_LABELS[month.month] || "挑戦を続けた月"
    end
  end
end
