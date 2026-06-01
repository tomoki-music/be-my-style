require "rails_helper"

RSpec.describe Singing::MmmConnectionBuilder do
  let(:customer) { create(:customer, domain_name: "singing") }

  def mission(title)
    Singing::MissionGenerator::Mission.new(
      title: title,
      description: "description",
      reason: "reason",
      difficulty: "やさしい",
      recommended_score: 90,
      coach_message: "coach"
    )
  end

  def growth_type(type_key)
    info = Singing::GrowthTypeAnalyzer::GROWTH_TYPES.fetch(type_key)
    Singing::GrowthTypeAnalyzer::Result.new(
      type_key: type_key,
      label: info[:label],
      icon: info[:icon],
      description: info[:description]
    )
  end

  def recommended_journey(type)
    challenge = Singing::ChallengeCircleBuilder::Challenge.new(
      id: type,
      title: type.to_s,
      description: "description",
      icon: "🎤",
      start_date: Time.current.beginning_of_week,
      end_date: Time.current.end_of_week,
      target_value: 3,
      challenge_type: type,
      participant_count: 0,
      completion_count: 0
    )

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

      expect(result).to be_a(described_class::MmmConnection)
      expect(result.title).to be_present
    end

    it "DTO返却と必須フィールドを満たす" do
      result = described_class.call(customer)

      expect(result.title).to be_present
      expect(result.message).to be_present
      expect(result.cta_label).to be_present
      expect(result.cta_url).to be_present
      expect(result.connection_type).to be_present
    end

    it "GrowthType別に分岐する" do
      3.times { create(:singing_diagnosis, :completed, customer: customer) }

      result = described_class.call(customer, growth_type: growth_type(:emotional_singer))

      expect(result.connection_type).to eq(:growth_type)
      expect(result.message).to include("気持ち")
      expect(result.cta_label).to eq("仲間を探す")
    end

    it "Mission別に分岐する" do
      3.times { create(:singing_diagnosis, :completed, customer: customer) }

      result = described_class.call(customer, mission: mission("感情を1つ決めて歌おう"))

      expect(result.connection_type).to eq(:event)
      expect(result.cta_label).to eq("イベントを見る")
      expect(result.cta_url).to eq("/public/events")
    end

    it "初心者にはイベント導線を返す" do
      result = described_class.call(customer, mission: mission("今月最初の一歩"))

      expect(result.connection_type).to eq(:event)
      expect(result.message).to include("初心者歓迎")
    end

    it "RecommendedJourneyからchallenge導線を返す" do
      3.times { create(:singing_diagnosis, :completed, customer: customer) }

      result = described_class.call(customer, recommended_journey: recommended_journey(:pitch_growth))

      expect(result.connection_type).to eq(:challenge)
      expect(result.cta_label).to eq("コミュニティを見る")
    end

    it "nil安全" do
      expect { described_class.call(nil, mission: nil, recommended_journey: nil, growth_type: nil) }.not_to raise_error
    end
  end
end
