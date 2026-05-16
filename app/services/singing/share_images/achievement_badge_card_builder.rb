module Singing
  module ShareImages
    class AchievementBadgeCardBuilder
      RARITY_LABELS = {
        common:    "NORMAL",
        rare:      "RARE",
        epic:      "EPIC",
        legendary: "LEGENDARY"
      }.freeze

      Card = Struct.new(
        :badge_key,
        :emoji,
        :badge_label,
        :short_label,
        :rarity,
        :rarity_label,
        :category,
        :headline,
        :earned_at_label,
        :subline,
        :x_share_text,
        keyword_init: true
      )

      def self.call(customer)
        new(customer).call
      end

      def initialize(customer)
        @customer = customer
      end

      def call
        return nil unless customer.present?

        stats = AchievementBadgeAggregator.call(customer)
        return nil if stats.nil?

        if stats.has_badges && stats.newest_badge.present?
          build_card_from_badge(stats.newest_badge, stats)
        else
          build_empty_card
        end
      end

      private

      attr_reader :customer

      def build_card_from_badge(badge, stats)
        defn = SingingAchievementBadge::BADGE_DEFINITIONS[badge.badge_key]
        return nil unless defn

        meta = badge.metadata.to_h

        Card.new(
          badge_key:       badge.badge_key,
          emoji:           defn[:emoji],
          badge_label:     defn[:label],
          short_label:     defn[:short_label],
          rarity:          defn[:rarity],
          rarity_label:    RARITY_LABELS[defn[:rarity]] || defn[:rarity].to_s.upcase,
          category:        defn[:category],
          headline:        build_headline(badge, defn, meta),
          earned_at_label: meta["earned_at_label"] || badge.earned_at.strftime("%Y年%-m月%-d日"),
          subline:         build_subline(badge, meta, stats),
          x_share_text:    build_share_text(defn, meta)
        )
      end

      def build_empty_card
        Card.new(
          badge_key:       nil,
          emoji:           "🎤",
          badge_label:     "Achievement Badge",
          short_label:     "Badge",
          rarity:          :common,
          rarity_label:    "NORMAL",
          category:        :milestone,
          headline:        "診断を重ねてバッジを獲得しよう！",
          earned_at_label: nil,
          subline:         "初めての診断を完了するとバッジが獲得できます",
          x_share_text:    "🎤 BeMyStyle Singing で歌声診断に挑戦中！ #BeMyStyle #Singing"
        )
      end

      def build_headline(badge, defn, meta)
        case badge.badge_key
        when "personal_best"
          delta = meta["score_delta"]
          score = meta["current_best_score"]
          delta.present? ? "#{score}点！自己ベストを#{delta}点更新" : "自己最高スコアを更新しました"
        when "streak_7"
          "7日間連続で歌い続けました"
        when "streak_30"
          "30日間連続達成！本当に続けられた"
        when "first_score_90"
          score = meta["overall_score"]
          score.present? ? "#{score}点！90点の壁を突破しました" : "90点以上を初めて獲得しました"
        when "growth_10"
          delta = meta["growth_delta"]
          delta.present? ? "初回から#{delta}点アップしました" : "スコアが10点以上伸びました"
        else
          defn[:description]
        end
      end

      def build_subline(badge, meta, stats)
        parts = []
        parts << "累計#{meta['diagnosis_count']}回診断" if meta["diagnosis_count"].present?
        parts << "バッジ#{stats.total_count}個獲得" if stats.total_count.to_i > 1
        parts.join(" / ").presence
      end

      def build_share_text(defn, _meta)
        defn[:share_text]
      end
    end
  end
end
