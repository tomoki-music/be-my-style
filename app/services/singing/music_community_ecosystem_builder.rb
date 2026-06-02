module Singing
  class MusicCommunityEcosystemBuilder
    ACTIVE_WINDOW_DAYS = 7

    MusicCommunityEcosystem = Struct.new(
      :active_members_count,
      :active_circles_count,
      :weekly_cheers_count,
      :weekly_challenges_count,
      :ecosystem_message,
      keyword_init: true
    )

    def self.call(customer: nil)
      new(customer: customer).call
    end

    def initialize(customer: nil)
      @customer = customer
    end

    def call
      MusicCommunityEcosystem.new(
        active_members_count:    active_members_count,
        active_circles_count:    active_circles_count,
        weekly_cheers_count:     weekly_cheers_count,
        weekly_challenges_count: weekly_challenges_count,
        ecosystem_message:       ecosystem_message
      )
    end

    private

    def active_window
      ACTIVE_WINDOW_DAYS.days.ago..Time.current
    end

    def active_members_count
      @active_members_count ||= SingingDiagnosis
        .completed
        .where(created_at: active_window)
        .distinct
        .count(:customer_id)
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      0
    end

    def active_circles_count
      all_configs = Singing::GrowthCirclesBuilder::GROWTH_TYPE_CIRCLES.values +
                    Singing::GrowthCirclesBuilder::MISSION_CIRCLES.values +
                    [Singing::GrowthCirclesBuilder::CHEER_CIRCLE_CONFIG]
      all_configs.count { |config| config[:member_count].to_i >= 1 }
    rescue StandardError
      0
    end

    def weekly_cheers_count
      @weekly_cheers_count ||= SingingCheerReaction
        .where(created_at: active_window)
        .count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      0
    end

    def weekly_challenges_count
      @weekly_challenges_count ||= SingingDailyChallengeProgress
        .where(completed_at: active_window)
        .count
    rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
      0
    end

    def ecosystem_message
      if active_members_count >= 50
        "今週もたくさんの仲間が歌を楽しんでいます🎵"
      elsif active_members_count >= 20
        "仲間たちの挑戦がコミュニティを盛り上げています✨"
      else
        "あなたの一歩がコミュニティを育てています🌱"
      end
    end
  end
end
