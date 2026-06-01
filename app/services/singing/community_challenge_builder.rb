module Singing
  class CommunityChallengeBuilder
    CommunityChallenge = Struct.new(
      :title,
      :participant_count,
      :cheer_count,
      :completion_count,
      :message,
      :challenge_key,
      keyword_init: true
    ) do
      def has_activity?
        participant_count.to_i.positive? || cheer_count.to_i.positive? || completion_count.to_i.positive?
      end
    end

    def self.call(customer, mission: nil, recommended_journey: nil, challenges: nil)
      new(customer, mission: mission, recommended_journey: recommended_journey, challenges: challenges).call
    end

    def initialize(customer, mission: nil, recommended_journey: nil, challenges: nil)
      @customer = customer
      @mission = mission
      @recommended_journey = recommended_journey
      @challenges = challenges
    end

    def call
      CommunityChallenge.new(
        title: "Community Challenge",
        participant_count: participant_count,
        cheer_count: cheer_count,
        completion_count: completion_count,
        message: build_message,
        challenge_key: challenge_key
      )
    end

    private

    def challenge_key
      @challenge_key ||= @recommended_journey&.challenge&.id || fallback_challenge_key
    end

    def fallback_challenge_key
      return :first_mission if @mission.nil?

      case @mission.title.to_s
      when /リズム/ then :rhythm_growth
      when /感情|表現/ then :expression_growth
      when /フレーズ|音/ then :pitch_growth
      when /1分|最初|一歩/ then :diagnosis_5
      else :todays_mission
      end
    end

    def participant_count
      @participant_count ||= begin
        count = @recommended_journey&.challenge&.participant_count.to_i
        count.positive? ? count : weekly_active_customer_count
      end
    end

    def cheer_count
      @cheer_count ||= begin
        return 0 unless defined?(SingingCheerReaction)

        SingingCheerReaction.where(created_at: week_range).count
      rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
        0
      end
    end

    def completion_count
      @completion_count ||= begin
        count = @recommended_journey&.challenge&.completion_count.to_i
        count.positive? ? count : computed_completion_count
      end
    end

    def weekly_active_customer_count
      SingingDiagnosis
        .completed
        .where(created_at: week_range)
        .distinct
        .count(:customer_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def computed_completion_count
      case challenge_key
      when :diagnosis_5
        weekly_diagnosis_completion_count
      when :pitch_growth
        score_growth_count(:pitch_score)
      when :rhythm_growth
        score_growth_count(:rhythm_score)
      when :expression_growth
        score_growth_count(:expression_score)
      else
        0
      end
    end

    def weekly_diagnosis_completion_count
      SingingDiagnosis
        .completed
        .where(created_at: week_range)
        .group(:customer_id)
        .having("COUNT(*) >= 5")
        .count
        .size
    end

    def score_growth_count(score_col)
      SingingDiagnosis
        .completed
        .where.not(score_col => nil)
        .where(created_at: 30.days.ago.beginning_of_day..Time.current)
        .group(:customer_id)
        .having("MAX(#{score_col}) - MIN(#{score_col}) >= 3")
        .count
        .size
    end

    def build_message
      if participant_count.to_i.zero? && cheer_count.to_i.zero? && completion_count.to_i.zero?
        "まだ挑戦者は少ないようです。あなたの一歩が、次の挑戦者を生み出します。"
      elsif completion_count.to_i.positive?
        "今週も達成した仲間がいます。焦らず、一緒に成長していきましょう。"
      elsif cheer_count.to_i.positive?
        "応援の空気が少しずつ広がっています。今日の挑戦も、きっと誰かの背中を押します。"
      else
        "同じ週に歌っている仲間がいます。ひとりじゃなく、一緒に進んでいきましょう。"
      end
    end

    def week_range
      now = Time.current
      now.beginning_of_week..now.end_of_week
    end
  end
end
