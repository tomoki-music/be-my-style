module Singing
  module ShareImages
    class MonthlyAchievementWrappedCardBuilder
      Card = Struct.new(
        :month_str,
        :month_label,
        :total_count,
        :rarity_counts,
        :has_legendary,
        :has_epic,
        :representative_badge,
        :headline,
        :growth_story,
        :x_share_text,
        keyword_init: true
      )

      def self.call(customer, month_str)
        new(customer, month_str).call
      end

      def initialize(customer, month_str)
        @customer  = customer
        @month_str = month_str.to_s
      end

      def call
        return nil unless customer.present?

        wrapped = Singing::MonthlyAchievementWrappedBuilder.call(customer, month_str)
        return nil if wrapped.empty?

        Card.new(
          month_str:            wrapped.month_str,
          month_label:          wrapped.month_label,
          total_count:          wrapped.total_count,
          rarity_counts:        wrapped.rarity_counts,
          has_legendary:        wrapped.has_legendary,
          has_epic:             wrapped.has_epic,
          representative_badge: wrapped.representative_badge,
          headline:             build_headline(wrapped),
          growth_story:         build_growth_story(wrapped),
          x_share_text:         build_share_text(wrapped)
        )
      end

      private

      attr_reader :customer, :month_str

      def build_headline(wrapped)
        if wrapped.has_legendary
          "Legendary 達成！#{wrapped.month_label}"
        elsif wrapped.has_epic
          "Epic 達成！#{wrapped.month_label}"
        else
          "#{wrapped.total_count}件の達成 — #{wrapped.month_label}"
        end
      end

      def build_growth_story(wrapped)
        first = wrapped.first_earned
        last  = wrapped.last_earned
        rep   = wrapped.representative_badge

        if first && last && first.badge_id != last.badge_id
          "#{first.emoji} #{first.label} から #{last.emoji} #{last.label} まで"
        elsif rep
          "#{rep.emoji} #{rep.label} を達成"
        else
          "#{wrapped.total_count}件の達成を積み重ねました"
        end
      end

      def build_share_text(wrapped)
        label = month_display(wrapped.month_str)
        parts = ["#{label}のAchievement Wrapped🏆"]
        if wrapped.has_legendary
          parts << "Legendary 達成！✨"
        elsif wrapped.has_epic
          parts << "Epic 達成！"
        end
        parts << "#{wrapped.total_count}件の達成を積み重ねました"
        if wrapped.representative_badge
          parts << "代表：#{wrapped.representative_badge.emoji} #{wrapped.representative_badge.label}"
        end
        parts << "#BeMyStyle #歌唱診断 #Achievement"
        parts.join(" ")
      end

      def month_display(str)
        date = Date.parse("#{str}-01")
        "#{date.year}年#{date.month}月"
      rescue ArgumentError
        str
      end
    end
  end
end
