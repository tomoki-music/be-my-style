module Singing
  module ShareImages
    class YearlyWrappedAggregator
      Stats = Struct.new(
        :year,
        :diagnosis_count,
        :best_score,
        :avg_score,
        :score_growth,
        :top_skill_label,
        :top_skill_delta,
        :top_month,
        :top_month_count,
        :ai_challenge_count,
        :longest_challenge_streak,
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
        @customer       = customer
        @reference_time = reference_time
      end

      def call
        return nil if customer.nil?
        return nil if diagnoses.empty?

        Stats.new(
          year:                     year,
          diagnosis_count:          diagnoses.size,
          best_score:               best_score,
          avg_score:                avg_score,
          score_growth:             score_growth,
          top_skill_label:          top_skill_label,
          top_skill_delta:          top_skill_delta,
          top_month:                top_month,
          top_month_count:          top_month_count,
          ai_challenge_count:       ai_challenge_count,
          longest_challenge_streak: longest_challenge_streak
        )
      end

      private

      attr_reader :customer, :reference_time

      def year
        reference_time.in_time_zone.year
      end

      def year_range
        reference_time.in_time_zone.all_year
      end

      def diagnoses
        @diagnoses ||= customer.singing_diagnoses
          .completed
          .where(created_at: year_range)
          .order(:created_at, :id)
          .to_a
      end

      def best_score
        diagnoses.filter_map(&:overall_score).max
      end

      def avg_score
        scores = diagnoses.filter_map(&:overall_score)
        return nil if scores.empty?

        (scores.sum.to_f / scores.size).round(1)
      end

      def score_growth
        scores = diagnoses.filter_map(&:overall_score)
        return nil if scores.size < 2

        scores.last.to_i - scores.first.to_i
      end

      def top_skill_label
        top_skill_entry&.first
      end

      def top_skill_delta
        top_skill_entry&.last
      end

      def top_skill_entry
        @top_skill_entry ||= begin
          best = SKILL_LABELS.filter_map do |attr, label|
            values = diagnoses.filter_map { |d| d.public_send(attr) }
            next if values.size < 2

            delta = values.last.to_i - values.first.to_i
            [label, delta]
          end.max_by { |_, delta| delta }

          best&.last.to_i.positive? ? best : nil
        end
      end

      def top_month
        month_entry&.first
      end

      def top_month_count
        month_entry&.last
      end

      def month_entry
        @month_entry ||= diagnoses
          .group_by { |d| d.created_at.in_time_zone.month }
          .max_by { |_, group| group.size }
          &.then { |month, group| [month, group.size] }
      end

      def ai_challenge_count
        @ai_challenge_count ||= customer.singing_ai_challenge_progresses
          .where(challenge_month: year_range)
          .where("tried = ? OR completed = ? OR next_diagnosis_planned = ?", true, true, true)
          .count
      end

      def longest_challenge_streak
        @longest_challenge_streak ||= begin
          dates = customer.singing_daily_challenge_progresses
            .where(completed_at: year_range)
            .order(:completed_at)
            .pluck(:completed_at)
            .map { |t| t.in_time_zone.to_date }
            .uniq
            .sort

          return 0 if dates.empty?

          max_streak   = 1
          curr_streak  = 1
          dates.each_cons(2) do |prev, curr|
            if curr == prev + 1
              curr_streak += 1
              max_streak = [max_streak, curr_streak].max
            else
              curr_streak = 1
            end
          end
          max_streak
        end
      end
    end
  end
end
