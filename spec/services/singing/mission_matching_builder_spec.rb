require "rails_helper"

RSpec.describe Singing::MissionMatchingBuilder do
  def mission(title:, description: "description")
    Singing::MissionGenerator::Mission.new(
      title: title,
      description: description,
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

  describe ".call" do
    it "customer nilでも生成される" do
      result = described_class.call(nil)

      expect(result).to be_a(described_class::MissionMatching)
      expect(result.title).to be_present
    end

    it "GrowthTypeなしでも生成される" do
      result = described_class.call(nil, growth_type: nil)

      expect(result.growth_type_key).to eq(:unknown)
      expect(result.message).to be_present
    end

    it "Missionなしでも生成される" do
      result = described_class.call(nil, mission: nil)

      expect(result.mission_key).to eq(:general)
      expect(result.message).to include("正解はありません")
    end

    it "DTO返却と必須フィールドを満たす" do
      result = described_class.call(nil, mission: mission(title: "感情を1つ決めて歌おう"))

      expect(result.title).to be_present
      expect(result.message).to be_present
      expect(result.matched_count).not_to be_nil
      expect(result.cta_label).to be_present
      expect(result.cta_url).to be_present
    end

    it "expression系に分岐する" do
      result = described_class.call(
        nil,
        mission: mission(title: "感情を1つ決めて歌おう"),
        growth_type: growth_type(:emotional_singer)
      )

      expect(result.mission_key).to eq(:expression)
      expect(result.title).to include("感情表現")
      expect(result.message).to include("あなただけではありません")
    end

    it "rhythm系に分岐する" do
      result = described_class.call(nil, mission: mission(title: "リズムに乗ってみよう"))

      expect(result.mission_key).to eq(:rhythm)
      expect(result.title).to include("リズム")
    end

    it "consistency系に分岐する" do
      result = described_class.call(nil, mission: mission(title: "1分だけ歌おう"))

      expect(result.mission_key).to eq(:consistency)
      expect(result.message).to include("継続")
    end

    it "voice系に分岐する" do
      result = described_class.call(nil, mission: mission(title: "短いフレーズを気持ちよく当てよう"))

      expect(result.mission_key).to eq(:voice)
      expect(result.title).to include("声")
    end

    it "nil安全" do
      expect { described_class.call(nil, mission: nil, growth_type: nil, recommended_journey: nil, community_challenge: nil) }.not_to raise_error
    end
  end
end
