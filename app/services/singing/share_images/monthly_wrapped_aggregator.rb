module Singing
  module ShareImages
    class MonthlyWrappedAggregator
      Stats = Struct.new(
        :year,
        :month,
        :diagnosis_count,
        :best_score,
        :avg_score,
        :prev_avg_score,
        :score_improvement,
        :top_skill_label,
        :top_skill_delta,
        :challenge_completed_count,
        :challenge_streak,
        keyword_init: true
      )

      SKILL_LABELS = {
        "pitch_score"      => "Pitch",
        "rhythm_score"     => "Rhythm",
        "expression_score" => "Expression"
      }.freeze

      def self.call(customer, reference_time: Time.current)
        new(customer, reference_time: reference_time).call
      end

      def initialize(customer, reference_time: Time.current)
        @customer = customer
        @reference_time = reference_time
      end

      def call
        return nil unless customer.present?
        return nil if diagnoses_this_month.empty?

        Stats.new(
          year: target_month.year,
          month: target_month.month,
          diagnosis_count: diagnosis_count,
          best_score: best_score,
          avg_score: avg_score,
          prev_avg_score: prev_avg_score,
          score_improvement: score_improvement,
          top_skill_label: top_skill_label,
          top_skill_delta: top_skill_delta,
          challenge_completed_count: challenge_completed_count,
          challenge_streak: challenge_streak
        )
      end

      private

      attr_reader :customer, :reference_time

      def target_month
        @target_month ||= reference_time.beginning_of_month
      end

      def month_range
        target_month.all_month
      end

      def prev_month_range
        (target_month - 1.month).all_month
      end

      def diagnoses_this_month
        @diagnoses_this_month ||= customer.singing_diagnoses
          .completed
          .where(created_at: month_range)
          .order(:created_at)
      end

      def diagnoses_prev_month
        @diagnoses_prev_month ||= customer.singing_diagnoses
          .completed
          .where(created_at: prev_month_range)
          .order(:created_at)
      end

      def diagnosis_count
        diagnoses_this_month.size
      end

      def best_score
        diagnoses_this_month.filter_map(&:overall_score).max
      end

      def avg_score
        scores = diagnoses_this_month.filter_map(&:overall_score)
        return nil if scores.empty?

        (scores.sum.to_f / scores.size).round(1)
      end

      def prev_avg_score
        scores = diagnoses_prev_month.filter_map(&:overall_score)
        return nil if scores.empty?

        (scores.sum.to_f / scores.size).round(1)
      end

      def score_improvement
        return nil if avg_score.nil? || prev_avg_score.nil?

        (avg_score - prev_avg_score).round(1)
      end

      def top_skill_label
        top = top_skill_entry
        top ? SKILL_LABELS[top[:skill]] : nil
      end

      def top_skill_delta
        top = top_skill_entry
        top ? top[:delta] : nil
      end

      def top_skill_entry
        @top_skill_entry ||= begin
          prev_avgs = skill_avgs(diagnoses_prev_month)
          curr_avgs = skill_avgs(diagnoses_this_month)

          SKILL_LABELS.keys.filter_map do |skill|
            next unless curr_avgs[skill] && prev_avgs[skill]

            delta = (curr_avgs[skill] - prev_avgs[skill]).round(1)
            { skill: skill, delta: delta }
          end.max_by { |e| e[:delta] }
        end
      end

      def skill_avgs(diagnoses)
        SKILL_LABELS.keys.each_with_object({}) do |skill, hash|
          scores = diagnoses.filter_map { |d| d.public_send(skill) }
          hash[skill] = scores.empty? ? nil : (scores.sum.to_f / scores.size).round(1)
        end
      end

      def challenge_dates_this_month
        @challenge_dates_this_month ||= customer.singing_daily_challenge_progresses
          .joins(:singing_daily_challenge)
          .where.not(completed_at: nil)
          .where(singing_daily_challenges: { challenge_date: month_range })
          .pluck("singing_daily_challenges.challenge_date")
          .to_set
      end

      def challenge_completed_count
        challenge_dates_this_month.size
      end

      def challenge_streak
        dates = customer.singing_daily_challenge_progresses
          .joins(:singing_daily_challenge)
          .where.not(completed_at: nil)
          .pluck("singing_daily_challenges.challenge_date")
          .to_set

        end_date = [target_month.end_of_month.to_date, Date.current].min
        count_consecutive_days(dates, end_date)
      end

      def count_consecutive_days(dates, date)
        count = 0
        while dates.include?(date)
          count += 1
          date -= 1.day
        end
        count
      end
    end
  end
end
