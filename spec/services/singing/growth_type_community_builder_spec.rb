require "rails_helper"

RSpec.describe Singing::GrowthTypeCommunityBuilder do
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

      expect(result).to be_a(described_class::GrowthTypeCommunity)
      expect(result.title).to be_present
    end

    it "GrowthTypeなしでも生成される" do
      result = described_class.call(nil, growth_type: nil)

      expect(result.growth_type_key).to eq(:unknown)
      expect(result.community_message).to include("正解はありません")
    end

    it "DTO返却と必須フィールドを満たす" do
      result = described_class.call(nil, growth_type: growth_type(:emotional_singer))

      expect(result.title).to be_present
      expect(result.community_message).to be_present
      expect(result.member_count).not_to be_nil
      expect(result.cta_label).to be_present
      expect(result.cta_url).to be_present
    end

    it "Emotional Singer向けの文言を返す" do
      result = described_class.call(nil, growth_type: growth_type(:emotional_singer))

      expect(result.growth_type_key).to eq(:emotional_singer)
      expect(result.title).to include("感情表現")
      expect(result.community_message).to include("気持ち")
    end

    it "Rhythm Explorer向けの文言を返す" do
      result = described_class.call(nil, growth_type: growth_type(:rhythm_explorer))

      expect(result.title).to include("リズム")
      expect(result.community_message).to include("リズム")
    end

    it "Consistency Hero向けの文言を返す" do
      result = described_class.call(nil, growth_type: growth_type(:consistency_hero))

      expect(result.title).to include("継続")
      expect(result.community_message).to include("積み重ね")
    end

    it "nil安全" do
      expect { described_class.call(nil, growth_type: nil) }.not_to raise_error
    end
  end
end
