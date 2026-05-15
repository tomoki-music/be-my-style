module Singing
  module ShareImages
    class YearlyWrappedCardBuilder
      Card = Struct.new(
        :year,
        :year_label,
        :diagnosis_count,
        :best_score,
        :best_score_label,
        :score_growth,
        :score_growth_label,
        :top_month,
        :top_month_count,
        :top_month_label,
        :top_skill_label,
        :top_skill_delta_label,
        :ai_challenge_count,
        :longest_challenge_streak,
        :headline,
        :message,
        :badge_label,
        :x_share_text,
        keyword_init: true
      )

      MONTH_NAMES = %w[1月 2月 3月 4月 5月 6月 7月 8月 9月 10月 11月 12月].freeze

      def self.call(customer, reference_time: Time.current)
        new(customer, reference_time: reference_time).call
      end

      def initialize(customer, reference_time: Time.current)
        @customer       = customer
        @reference_time = reference_time
      end

      def call
        return nil if customer.nil?

        stats = YearlyWrappedAggregator.call(customer, reference_time: reference_time)
        return nil if stats.nil?

        Card.new(
          year:                     stats.year,
          year_label:               "#{stats.year}年",
          diagnosis_count:          stats.diagnosis_count,
          best_score:               stats.best_score,
          best_score_label:         best_score_label(stats),
          score_growth:             stats.score_growth,
          score_growth_label:       score_growth_label(stats),
          top_month:                stats.top_month,
          top_month_count:          stats.top_month_count,
          top_month_label:          top_month_label(stats),
          top_skill_label:          stats.top_skill_label,
          top_skill_delta_label:    top_skill_delta_label(stats),
          ai_challenge_count:       stats.ai_challenge_count,
          longest_challenge_streak: stats.longest_challenge_streak,
          headline:                 headline(stats),
          message:                  message(stats),
          badge_label:              "Yearly Wrapped",
          x_share_text:             Singing::ShareTextBuilder.yearly_wrapped(customer, reference_time: reference_time, stats: stats)
        )
      end

      private

      attr_reader :customer, :reference_time

      def best_score_label(stats)
        stats.best_score.present? ? "最高スコア #{stats.best_score}点" : "記録前"
      end

      def score_growth_label(stats)
        return "初年度" if stats.score_growth.nil?

        delta = stats.score_growth.to_i
        if delta.positive?
          "+#{delta}点"
        elsif delta.negative?
          "#{delta}点"
        else
          "変動なし"
        end
      end

      def top_month_label(stats)
        return nil unless stats.top_month.present?

        month_name = MONTH_NAMES[stats.top_month - 1]
        "#{month_name}が一番頑張った（#{stats.top_month_count}回）"
      end

      def top_skill_delta_label(stats)
        return nil unless stats.top_skill_label.present? && stats.top_skill_delta.to_i.positive?

        "#{stats.top_skill_label} +#{stats.top_skill_delta}pt"
      end

      def headline(stats)
        if stats.top_skill_label.present? && stats.top_skill_delta.to_i.positive?
          "#{stats.top_skill_label}が今年いちばん伸びた"
        elsif stats.score_growth.to_i.positive?
          "今年、ちゃんと声が変わっていた"
        elsif stats.diagnosis_count >= 5
          "今年も#{stats.diagnosis_count}回、声と向き合った"
        else
          "今年の声の記録をはじめた"
        end
      end

      def message(stats)
        if stats.score_growth.to_i.positive?
          "#{stats.year}年、あなたの声は確かに育っていました。小さな積み重ねが、ここに刻まれています。"
        elsif stats.diagnosis_count >= 3
          "#{stats.year}年は#{stats.diagnosis_count}回、自分の声を聴き直しました。それだけで、十分な一歩です。"
        else
          "#{stats.year}年の声の記録がはじまりました。続けるほど、変化の輪郭が見えてきます。"
        end
      end
    end
  end
end
