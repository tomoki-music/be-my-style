require "rails_helper"

RSpec.describe Singing::SessionRecommendationBuilder do
  def mission_matching(key)
    Singing::MissionMatchingBuilder::MissionMatching.new(
      title: "title",
      message: "message",
      growth_type_key: :unknown,
      mission_key: key,
      matched_count: 10,
      cta_label: "仲間を見てみる",
      cta_url: "/public/communities/7"
    )
  end

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

  describe ".call" do
    it "customer nilでも生成される" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::SessionRecommendation)
      expect(result.title).to be_present
    end

    it "Missionなしでも生成される" do
      result = described_class.call(nil, mission: nil, mission_matching: nil)

      expect(result.event_name).to be_present
      expect(result.message).to be_present
    end

    it "DTO返却と必須フィールドを満たす" do
      result = described_class.call(nil, mission_matching: mission_matching(:expression))

      expect(result.title).to be_present
      expect(result.message).to be_present
      expect(result.event_name).to be_present
      expect(result.event_url).to be_present
      expect(result.reason).to be_present
      expect(result.cta_label).to be_present
    end

    it "expression系はアコースティックセッションを返す" do
      result = described_class.call(nil, mission_matching: mission_matching(:expression))

      expect(result.recommended_type).to eq(:acoustic)
      expect(result.event_name).to eq("アコースティックセッション")
      expect(result.reason).to include("表現")
    end

    it "rhythm系はバンドセッションを返す" do
      result = described_class.call(nil, mission_matching: mission_matching(:rhythm))

      expect(result.recommended_type).to eq(:band)
      expect(result.event_name).to eq("バンドセッション")
    end

    it "consistency系は初心者歓迎セッションを返す" do
      result = described_class.call(nil, mission_matching: mission_matching(:consistency))

      expect(result.recommended_type).to eq(:beginner)
      expect(result.event_name).to eq("初心者歓迎セッション")
    end

    it "voice系はボーカル向けセッションを返す" do
      result = described_class.call(nil, mission_matching: mission_matching(:voice))

      expect(result.recommended_type).to eq(:vocal)
      expect(result.event_name).to eq("ボーカル向けセッション")
    end

    it "Missionテキストからも推薦できる" do
      result = described_class.call(nil, mission: mission("リズムに乗ってみよう"))

      expect(result.recommended_type).to eq(:band)
    end

    it "nil安全" do
      expect { described_class.call(nil, mission: nil, mission_matching: nil, growth_type: nil, recommended_journey: nil, mmm_connection: nil) }.not_to raise_error
    end
  end
end
