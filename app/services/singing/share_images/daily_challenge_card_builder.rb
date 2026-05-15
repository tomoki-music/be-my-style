require "set"

module Singing
  module ShareImages
    class DailyChallengeCardBuilder
      Card = Struct.new(
        :streak_days,
        :completed_today,
        :score_delta,
        :headline,
        :subheadline,
        :message,
        :badge_label,
        :score_delta_label,
        :challenge_title,
        :challenge_icon,
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

        Card.new(
          streak_days: streak_days,
          completed_today: completed_today?,
          score_delta: score_delta,
          headline: headline,
          subheadline: subheadline,
          message: message,
          badge_label: "Daily Challenge",
          score_delta_label: score_delta_label,
          challenge_title: challenge&.title || "今日のチャレンジ",
          challenge_icon: challenge&.target_icon || "🎤",
          x_share_text: x_share_text
        )
      end

      private

      attr_reader :customer, :reference_time

      def today
        reference_time.to_date
      end

      def challenge
        @challenge ||= Singing::DailyChallengeGenerator.ensure_today
      end

      def progress
        @progress ||= challenge&.progress_for(customer)
      end

      def completed_today?
        !!(progress&.completed? && progress.completed_at&.to_date == today)
      end

      def streak_days
        @streak_days ||= begin
          dates = customer.singing_daily_challenge_progresses
            .joins(:singing_daily_challenge)
            .where.not(completed_at: nil)
            .pluck("singing_daily_challenges.challenge_date")
            .to_set

          count_consecutive_days(dates, completed_today? ? today : today - 1.day)
        end
      end

      def count_consecutive_days(dates, date)
        count = 0
        while dates.include?(date)
          count += 1
          date -= 1.day
        end
        count
      end

      def latest_today_diagnosis
        @latest_today_diagnosis ||= customer.singing_diagnoses
          .completed
          .where(created_at: today.all_day)
          .order(created_at: :desc, id: :desc)
          .first
      end

      def previous_diagnosis
        @previous_diagnosis ||= begin
          return nil unless latest_today_diagnosis

          latest_today_diagnosis.previous_completed_diagnosis
        end
      end

      def score_delta
        @score_delta ||= begin
          return nil unless latest_today_diagnosis && previous_diagnosis
          return nil if latest_today_diagnosis.overall_score.blank? || previous_diagnosis.overall_score.blank?

          latest_today_diagnosis.overall_score.to_i - previous_diagnosis.overall_score.to_i
        end
      end

      def headline
        return "#{streak_days}日継続中" if streak_days >= 2
        return "今日も歌いました" if completed_today?

        "今日の一歩を準備中"
      end

      def subheadline
        return "今日も歌の練習を完了しました" if completed_today?

        "次の診断で今日の挑戦を残せます"
      end

      def message
        return "前回より少し前に進みました" if score_delta.to_i.positive?

        "小さな一歩を積み重ねています"
      end

      def score_delta_label
        return nil if score_delta.nil?
        return "+#{score_delta}点" if score_delta.positive?

        "記録を更新中"
      end

      def x_share_text
        Singing::ShareTextBuilder.daily_challenge(
          customer,
          reference_time: reference_time,
          card: Card.new(
            streak_days: streak_days,
            completed_today: completed_today?,
            score_delta: score_delta
          )
        )
      end
    end
  end
end
