module Singing
  class DailyChallengeEvaluator
    Result = Struct.new(:completed, :xp_awarded, :challenge, keyword_init: true)

    def self.call(diagnosis)
      new(diagnosis).call
    end

    def initialize(diagnosis)
      @diagnosis = diagnosis
      @customer  = diagnosis.customer
    end

    def call
      return nil unless @diagnosis.completed? && @customer

      challenge = Singing::DailyChallengeGenerator.ensure_today
      return nil if challenge.completed_by?(@customer)

      return nil unless meets_challenge?(challenge)

      award!(challenge)
    end

    private

    def meets_challenge?(challenge)
      case challenge.challenge_type
      when "score_threshold"
        score = @diagnosis.public_send(challenge.score_column)
        score.present? && score >= challenge.threshold_value
      when "count"
        today_count = @customer.singing_diagnoses
          .completed
          .where(created_at: Date.current.all_day)
          .count
        today_count >= challenge.threshold_value
      else
        false
      end
    end

    def award!(challenge)
      progress = SingingDailyChallengeProgress.create!(
        customer:                 @customer,
        singing_daily_challenge:  challenge,
        completed_at:             Time.current,
        xp_rewarded:              challenge.xp_reward
      )

      @customer.update_columns(
        singing_xp:    @customer.singing_xp + challenge.xp_reward,
        singing_level: Singing::SingerRankService.level_for_xp(@customer.singing_xp + challenge.xp_reward)
      )

      Result.new(completed: true, xp_awarded: challenge.xp_reward, challenge: challenge)
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end
