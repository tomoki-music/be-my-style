require "rails_helper"

RSpec.describe Singing::CommunityChallengeBuilder do
  let(:customer) { create(:customer, domain_name: "singing") }

  def challenge(id:, type:)
    Singing::ChallengeCircleBuilder::Challenge.new(
      id: id,
      title: id.to_s,
      description: "description",
      icon: "🎤",
      start_date: Time.current.beginning_of_week,
      end_date: Time.current.end_of_week,
      target_value: 5,
      challenge_type: type,
      participant_count: 0,
      completion_count: 0
    )
  end

  def recommended_for(challenge)
    Singing::RecommendedJourneyBuilder::Result.new(
      challenge: challenge,
      progress: nil,
      coach_label: "優しい先生",
      coach_icon: "🌿",
      title: "おすすめ",
      message: "message",
      reason: "reason",
      action_label: "挑戦する"
    )
  end

  describe ".call" do
    it "customer nilでも生成される" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::CommunityChallenge)
      expect(result.participant_count).not_to be_nil
    end

    it "challengeなしでも生成される" do
      result = described_class.call(customer)

      expect(result).to be_a(described_class::CommunityChallenge)
      expect(result.challenge_key).to eq(:first_mission)
    end

    it "DTOが返り、各countがnilにならない" do
      result = described_class.call(customer)

      expect(result.title).to be_present
      expect(result.participant_count).not_to be_nil
      expect(result.cheer_count).not_to be_nil
      expect(result.completion_count).not_to be_nil
      expect(result.message).to be_present
    end

    it "challenge_keyが保持される" do
      rhythm = challenge(id: :rhythm_growth, type: :rhythm_growth)
      result = described_class.call(customer, recommended_journey: recommended_for(rhythm))

      expect(result.challenge_key).to eq(:rhythm_growth)
    end

    it "仲間0人でも前向きメッセージになる" do
      result = described_class.call(customer)

      expect(result.participant_count).to eq(0)
      expect(result.cheer_count).to eq(0)
      expect(result.completion_count).to eq(0)
      expect(result.message).to include("あなたの一歩")
    end

    it "今週の挑戦者数を集計する" do
      create(:singing_diagnosis, :completed, customer: customer)
      other = create(:customer, domain_name: "singing")
      create(:singing_diagnosis, :completed, customer: other)

      result = described_class.call(customer)

      expect(result.participant_count).to be >= 2
      expect(result.message).to include("仲間")
    end

    it "nil安全" do
      expect { described_class.call(nil, mission: nil, recommended_journey: nil, challenges: nil) }.not_to raise_error
    end
  end
end
