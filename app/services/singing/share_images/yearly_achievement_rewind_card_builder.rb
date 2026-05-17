module Singing
  module ShareImages
    class YearlyAchievementRewindCardBuilder
      Card = Struct.new(
        :year,
        :total_count,
        :milestone_count,
        :has_legendary,
        :has_epic,
        :representative_badge,
        :rarity_counts,
        :headline,
        :growth_story,
        :x_share_text,
        keyword_init: true
      )

      def self.call(customer, year:)
        new(customer, year: year).call
      end

      def initialize(customer, year:)
        @customer = customer
        @year     = year.to_i
      end

      def call
        return nil unless customer.present?

        rewind = Singing::YearlyAchievementRewindBuilder.call(customer, year: @year)
        return nil if rewind.empty?

        Card.new(
          year:                @year,
          total_count:         rewind.total_count,
          milestone_count:     rewind.milestone_count,
          has_legendary:       rewind.has_legendary,
          has_epic:            rewind.has_epic,
          representative_badge: rewind.representative_badge,
          rarity_counts:       rewind.rarity_counts,
          headline:            build_headline(rewind),
          growth_story:        build_growth_story(rewind),
          x_share_text:        build_share_text(rewind)
        )
      end

      private

      attr_reader :customer

      def build_headline(rewind)
        if rewind.has_legendary
          "Legendary 達成！#{@year}年の挑戦"
        elsif rewind.has_epic
          "Epic 達成！#{@year}年の記録"
        else
          "#{@year}年 — #{rewind.total_count}件の達成"
        end
      end

      def build_growth_story(rewind)
        first = rewind.first_earned
        last  = rewind.last_earned
        rep   = rewind.representative_badge

        if first && last && first.badge_id != last.badge_id
          "#{first.emoji} #{first.label} から #{last.emoji} #{last.label} まで"
        elsif rep
          "#{rep.emoji} #{rep.label} を達成した1年"
        else
          "#{rewind.total_count}件の達成を積み重ねた1年"
        end
      end

      def build_share_text(rewind)
        parts = ["#{@year}年のAchievement Rewind🏆"]
        if rewind.has_legendary
          parts << "Legendary 達成！✨"
        elsif rewind.has_epic
          parts << "Epic 達成！"
        end
        parts << "#{rewind.total_count}件の達成を積み重ねました"
        if rewind.representative_badge
          parts << "代表：#{rewind.representative_badge.emoji} #{rewind.representative_badge.label}"
        end
        parts << "#BeMyStyle #歌唱診断 #AchievementRewind"
        parts.join(" ")
      end
    end
  end
end
