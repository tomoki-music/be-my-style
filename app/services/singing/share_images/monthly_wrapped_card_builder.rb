module Singing
  module ShareImages
    class MonthlyWrappedCardBuilder
      Card = Struct.new(
        :year,
        :month,
        :month_label,
        :diagnosis_count,
        :best_score,
        :best_score_label,
        :score_improvement,
        :score_improvement_label,
        :top_skill_label,
        :top_skill_delta,
        :top_skill_delta_label,
        :challenge_completed_count,
        :challenge_streak,
        :headline,
        :message,
        :badge_label,
        :x_share_text,
        keyword_init: true
      )

      def self.call(customer, reference_time: Time.current)
        new(customer, reference_time: reference_time).call
      end

      def initialize(customer, reference_time: Time.current)
        @customer = customer
        @reference_time = reference_time
      end

      def call
        return nil unless customer.present?

        stats = MonthlyWrappedAggregator.call(customer, reference_time: reference_time)
        return nil if stats.nil?

        Card.new(
          year: stats.year,
          month: stats.month,
          month_label: month_label(stats),
          diagnosis_count: stats.diagnosis_count,
          best_score: stats.best_score,
          best_score_label: best_score_label(stats),
          score_improvement: stats.score_improvement,
          score_improvement_label: score_improvement_label(stats),
          top_skill_label: stats.top_skill_label,
          top_skill_delta: stats.top_skill_delta,
          top_skill_delta_label: top_skill_delta_label(stats),
          challenge_completed_count: stats.challenge_completed_count,
          challenge_streak: stats.challenge_streak,
          headline: headline(stats),
          message: message(stats),
          badge_label: "Monthly Wrapped",
          x_share_text: x_share_text(stats)
        )
      end

      private

      attr_reader :customer, :reference_time

      def month_label(stats)
        "#{stats.year}年#{stats.month}月"
      end

      def best_score_label(stats)
        return "スコア未記録" if stats.best_score.nil?

        "最高スコア #{stats.best_score}点"
      end

      def score_improvement_label(stats)
        improvement = stats.score_improvement
        return "前月データなし" if improvement.nil?
        return "前月比 +#{improvement}点" if improvement.positive?
        return "前月比 ±0点" if improvement.zero?

        "前月比 #{improvement}点"
      end

      def top_skill_delta_label(stats)
        return nil if stats.top_skill_label.nil? || stats.top_skill_delta.nil?
        return "#{stats.top_skill_label} +#{stats.top_skill_delta}点" if stats.top_skill_delta.positive?

        stats.top_skill_label
      end

      def headline(stats)
        count = stats.diagnosis_count
        return "#{count}回歌いました" if count >= 5
        return "#{count}回挑戦しました" if count >= 2

        "今月も歌いました"
      end

      def message(stats)
        if stats.score_improvement.to_f.positive? && stats.top_skill_label.present?
          "#{stats.top_skill_label}が伸びた月でした"
        elsif stats.score_improvement.to_f.positive?
          "着実に前に進んでいます"
        elsif stats.challenge_streak.to_i >= 7
          "継続が、あなたの力になっています"
        else
          "歌を続けることが、あなたの成長です"
        end
      end

      def x_share_text(stats)
        Singing::ShareTextBuilder.monthly_wrapped(customer, reference_time: reference_time, stats: stats)
      end
    end
  end
end
