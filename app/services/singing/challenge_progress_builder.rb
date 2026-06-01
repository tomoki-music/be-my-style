module Singing
  class ChallengeProgressBuilder
    Progress = Struct.new(
      :challenge,
      :current_value,
      :target_value,
      :progress_ratio,
      :completed,
      keyword_init: true
    ) do
      def progress_percent
        (progress_ratio * 100).round.clamp(0, 100)
      end

      def progress_label
        "#{current_value} / #{target_value}"
      end
    end

    def self.call(customer, challenges: nil)
      new(customer, challenges: challenges).call
    end

    def initialize(customer, challenges: nil)
      @customer   = customer
      @challenges = challenges || Singing::ChallengeCircleBuilder.call
    end

    def call
      return [] if @customer.nil?

      @challenges.map { |challenge| build_progress(challenge) }
    end

    private

    def build_progress(challenge)
      current = compute_current(challenge)
      target  = challenge.target_value
      ratio   = target.to_i.zero? ? 0.0 : [(current.to_f / target), 1.0].min

      Progress.new(
        challenge:      challenge,
        current_value:  current,
        target_value:   target,
        progress_ratio: ratio,
        completed:      ratio >= 1.0
      )
    end

    def compute_current(challenge)
      case challenge.challenge_type
      when :streak             then compute_streak
      when :diagnosis_count    then compute_diagnosis_count
      when :pitch_growth       then compute_score_growth(:pitch_score)
      when :rhythm_growth      then compute_score_growth(:rhythm_score)
      when :expression_growth  then compute_score_growth(:expression_score)
      when :theme              then compute_theme_count
      else 0
      end
    end

    # ─── 個別進捗計算 ──────────────────────────────────────────────────

    def compute_streak
      Singing::StreakCalculator.call(@customer)
    end

    def compute_diagnosis_count
      now = Time.current
      @customer.singing_diagnoses
               .completed
               .where(created_at: now.beginning_of_week..now.end_of_week)
               .count
    end

    def compute_score_growth(score_attr)
      scores = @customer.singing_diagnoses
                        .completed
                        .where.not(score_attr => nil)
                        .order(created_at: :desc, id: :desc)
                        .limit(5)
                        .pluck(score_attr)
      return 0 if scores.size < 2

      [scores.first - scores.last, 0].max
    end

    def compute_theme_count
      now = Time.current
      range = now.beginning_of_month..now.end_of_month
      base  = @customer.singing_diagnoses.completed.where(created_at: range)

      Singing::ChallengeCircleBuilder::ANISON_KEYWORDS
        .reduce(base.none) { |s, kw| s.or(base.where("song_title LIKE ?", "%#{kw}%")) }
        .count
    end
  end
end
