class Singing::ChallengesController < Singing::BaseController
  def index
    @challenge_experience = Singing::ChallengeExperienceBuilder.call(current_customer)
    @challenges = @challenge_experience.challenges
    @progresses = @challenge_experience.progresses
    @progress_by_id = @challenge_experience.progress_by_id
    @can_see_premium = @challenge_experience.can_see_premium
    @recommended_journey = @challenge_experience.recommended_journey
    @personal_growth_roadmap = @challenge_experience.personal_growth_roadmap
    @todays_mission = @challenge_experience.todays_mission
    @mission_matching = @challenge_experience.mission_matching
    @session_recommendation = @challenge_experience.session_recommendation
    @community_challenge = @challenge_experience.community_challenge
    @growth_type_community = @challenge_experience.growth_type_community
    @mmm_connection = @challenge_experience.mmm_connection
  end
end
