module Singing
  class CommunityReputationBuilder
    POINTS_PER_DIAGNOSIS    = 1
    POINTS_PER_CHEER        = 2
    POINTS_PER_CHALLENGE    = 5
    POINTS_PER_PARTICIPATION = 3

    LEVELS = [
      { name: :seed,             min: 0,    title: "🌱 Seed" },
      { name: :supporter,        min: 50,   title: "🤝 Supporter" },
      { name: :performer,        min: 150,  title: "🎤 Performer" },
      { name: :community_star,   min: 300,  title: "⭐ Community Star" },
      { name: :music_partner,    min: 600,  title: "🎵 Music Partner" },
      { name: :music_ambassador, min: 1000, title: "👑 Music Ambassador" }
    ].freeze

    MESSAGES = {
      seed:             "あなたの一歩がコミュニティを育てています🌱",
      supporter:        "仲間への応援が広がっています🤝",
      performer:        "あなたの挑戦が周囲を刺激しています🎤",
      community_star:   "コミュニティを支える存在です⭐",
      music_partner:    "音楽を楽しむ輪の中心にいます🎵",
      music_ambassador: "多くの仲間へ良い影響を届けています👑"
    }.freeze

    CommunityReputation = Struct.new(
      :reputation_level,
      :reputation_title,
      :reputation_points,
      :streak_points,
      :challenge_points,
      :cheer_points,
      :participation_points,
      :next_level_points,
      :progress_percent,
      :reputation_message,
      keyword_init: true
    )

    def self.call(customer:)
      new(customer: customer).call
    end

    def initialize(customer:)
      @customer = customer
    end

    def call
      return nil if @customer.nil?

      CommunityReputation.new(
        reputation_level:     level_name,
        reputation_title:     level_title,
        reputation_points:    total_points,
        streak_points:        streak_points,
        challenge_points:     challenge_points,
        cheer_points:         cheer_points,
        participation_points: participation_points,
        next_level_points:    next_level_points,
        progress_percent:     progress_percent,
        reputation_message:   MESSAGES[level_name]
      )
    end

    private

    def total_points
      @total_points ||= streak_points + challenge_points + cheer_points + participation_points
    end

    def streak_points
      @streak_points ||= diagnosis_count * POINTS_PER_DIAGNOSIS
    end

    def cheer_points
      @cheer_points ||= cheer_count * POINTS_PER_CHEER
    end

    def challenge_points
      @challenge_points ||= challenge_count * POINTS_PER_CHALLENGE
    end

    def participation_points
      @participation_points ||= participation_count * POINTS_PER_PARTICIPATION
    end

    def diagnosis_count
      @diagnosis_count ||= @customer.singing_diagnoses.completed.count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def cheer_count
      @cheer_count ||= @customer.singing_cheer_reactions.count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def challenge_count
      @challenge_count ||= @customer
        .singing_daily_challenge_progresses
        .where.not(completed_at: nil)
        .count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def participation_count
      @participation_count ||= @customer.join_part_customers.count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NoMethodError
      0
    end

    def current_level
      @current_level ||= LEVELS.reverse.find { |l| total_points >= l[:min] } || LEVELS.first
    end

    def next_level
      @next_level ||= begin
        idx = LEVELS.index(current_level)
        LEVELS[idx + 1]
      end
    end

    def level_name
      current_level[:name]
    end

    def level_title
      current_level[:title]
    end

    def next_level_points
      return 0 if next_level.nil?

      next_level[:min] - total_points
    end

    def progress_percent
      return 100 if next_level.nil?

      level_range = next_level[:min] - current_level[:min]
      return 0 if level_range <= 0

      earned = [total_points - current_level[:min], 0].max
      [(earned.to_f / level_range * 100).round, 100].min
    end
  end
end
