require "rails_helper"

RSpec.describe Singing::ChallengeExperienceBuilder do
  describe ".call" do
    let(:customer) { create(:customer, domain_name: "singing") }

    it "Challenge Circleに必要なDTOをまとめて返す" do
      experience = described_class.call(customer)

      expect(experience.challenges).to be_present
      expect(experience.progresses).to be_present
      expect(experience.progress_by_id).to be_a(Hash)
      expect(experience.todays_mission).to be_a(Singing::MissionGenerator::Mission)
      expect(experience.mission_matching).to be_a(Singing::MissionMatchingBuilder::MissionMatching)
      expect(experience.session_recommendation).to be_a(Singing::SessionRecommendationBuilder::SessionRecommendation)
      expect(experience.personal_growth_roadmap).to be_a(Singing::PersonalGrowthRoadmapBuilder::Roadmap)
      expect(experience.community_challenge).to be_a(Singing::CommunityChallengeBuilder::CommunityChallenge)
      expect(experience.growth_type_community).to be_a(Singing::GrowthTypeCommunityBuilder::GrowthTypeCommunity)
      expect(experience.mmm_connection).to be_a(Singing::MmmConnectionBuilder::MmmConnection)
    end

    it "customer nilでも落ちずに体験DTOを返す" do
      experience = described_class.call(nil)

      expect(experience.challenges).to be_present
      expect(experience.progresses).to eq([])
      expect(experience.can_see_premium).to be false
      expect(experience.todays_mission).to be_present
      expect(experience.mission_matching).to be_present
      expect(experience.session_recommendation).to be_present
      expect(experience.community_challenge).to be_present
      expect(experience.growth_type_community).to be_present
      expect(experience.mmm_connection).to be_present
    end

    it "progress_by_id は progress の challenge id をキーにする" do
      experience = described_class.call(customer)

      expect(experience.progress_by_id.keys).to match_array(experience.progresses.map { |progress| progress.challenge.id })
    end
  end
end
