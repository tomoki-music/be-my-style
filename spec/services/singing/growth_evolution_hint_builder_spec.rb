require "rails_helper"

RSpec.describe Singing::GrowthEvolutionHintBuilder do
  describe ".call" do
    Singing::GrowthTypeAnalyzer::GROWTH_TYPES.each_key do |type_key|
      it "#{type_key} のヒントを返すこと" do
        result = described_class.call(type_key)
        expect(result.hint).to be_present
      end
    end

    context "groove_builder" do
      it "Rhythm Explorer へのヒントを含むこと" do
        result = described_class.call(:groove_builder)
        expect(result.hint).to include("Rhythm Explorer")
      end
    end

    context "rhythm_explorer" do
      it "Emotional Singer へのヒントを含むこと" do
        result = described_class.call(:rhythm_explorer)
        expect(result.hint).to include("Emotional Singer")
      end
    end

    context "emotional_singer" do
      it "Dynamic Performer へのヒントを含むこと" do
        result = described_class.call(:emotional_singer)
        expect(result.hint).to include("Dynamic Performer")
      end
    end

    context "voice_challenger" do
      it "Consistency Hero へのヒントを含むこと" do
        result = described_class.call(:voice_challenger)
        expect(result.hint).to include("Consistency Hero")
      end
    end

    context "string で渡した場合" do
      it "シンボルと同じヒントを返すこと" do
        expect(described_class.call("groove_builder").hint).to eq(described_class.call(:groove_builder).hint)
      end
    end

    context "未知の type_key の場合" do
      it "フォールバックして hint が存在すること" do
        result = described_class.call(:unknown_type)
        expect(result.hint).to be_present
      end
    end
  end
end
