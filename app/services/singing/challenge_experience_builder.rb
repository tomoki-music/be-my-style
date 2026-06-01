module Singing
  class ChallengeExperienceBuilder
    Experience = Struct.new(
      :challenges,
      :progresses,
      :progress_by_id,
      :can_see_premium,
      :recommended_journey,
      :personal_growth_roadmap,
      :todays_mission,
      :mission_matching,
      :session_recommendation,
      :community_challenge,
      :growth_type,
      :growth_type_community,
      :mmm_connection,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      challenges = Singing::ChallengeCircleBuilder.call
      progresses = Singing::ChallengeProgressBuilder.call(@customer, challenges: challenges)
      can_see_premium = @customer&.has_feature?(:singing_growth_circle_all_badges) || false
      growth_type = Singing::GrowthTypeAnalyzer.call(@customer)
      recommended = Singing::RecommendedJourneyBuilder.call(
        @customer,
        progresses: progresses,
        include_premium: can_see_premium
      )
      roadmap = Singing::PersonalGrowthRoadmapBuilder.call(
        @customer,
        progresses: progresses,
        recommended_journey: recommended,
        include_premium: can_see_premium
      )
      mission = Singing::MissionGenerator.call(
        @customer,
        recommended_journey: recommended,
        roadmap: roadmap,
        progresses: progresses,
        include_premium: can_see_premium
      )
      community = Singing::CommunityChallengeBuilder.call(
        @customer,
        mission: mission,
        recommended_journey: recommended,
        challenges: challenges
      )
      mission_matching = Singing::MissionMatchingBuilder.call(
        @customer,
        mission: mission,
        growth_type: growth_type,
        recommended_journey: recommended,
        community_challenge: community
      )
      session_recommendation = Singing::SessionRecommendationBuilder.call(
        @customer,
        mission: mission,
        mission_matching: mission_matching,
        growth_type: growth_type,
        recommended_journey: recommended
      )
      growth_type_community = Singing::GrowthTypeCommunityBuilder.call(
        @customer,
        growth_type: growth_type
      )
      mmm_connection = Singing::MmmConnectionBuilder.call(
        @customer,
        mission: mission,
        recommended_journey: recommended,
        growth_type: growth_type
      )

      Experience.new(
        challenges: challenges,
        progresses: progresses,
        progress_by_id: progresses.index_by { |progress| progress.challenge.id },
        can_see_premium: can_see_premium,
        recommended_journey: recommended,
        personal_growth_roadmap: roadmap,
        todays_mission: mission,
        mission_matching: mission_matching,
        session_recommendation: session_recommendation,
        community_challenge: community,
        growth_type: growth_type,
        growth_type_community: growth_type_community,
        mmm_connection: mmm_connection
      )
    end
  end
end
