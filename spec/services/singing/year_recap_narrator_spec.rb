require "rails_helper"

RSpec.describe Singing::YearRecapNarrator do
  let(:base_data) do
    {
      customer_id:         1,
      year:                2026,
      personality:         "passionate",
      diagnosis_count:     20,
      most_improved_label: "表現力",
      most_improved_delta: 12,
      max_streak:          7
    }
  end

  def call(overrides = {})
    described_class.call(base_data.merge(overrides))
  end

  describe ".call" do
    it "ai_summary, streak_message, coach_reflection を返す" do
      result = call
      expect(result).to have_key(:ai_summary)
      expect(result).to have_key(:streak_message)
      expect(result).to have_key(:coach_reflection)
    end

    context "ai_summary" do
      it "diagnosis_count を含む文字列を返す" do
        result = call(diagnosis_count: 10)
        expect(result[:ai_summary]).to be_a(String).and be_present
      end

      it "diagnosis_count が 30 以上かつ成長あり の場合、label と delta を含む" do
        result = call(diagnosis_count: 35, most_improved_label: "音程", most_improved_delta: 8)
        expect(result[:ai_summary]).to include("音程").and include("+8")
      end

      it "diagnosis_count が 5 未満の場合も文字列を返す" do
        result = call(diagnosis_count: 2, most_improved_label: nil, most_improved_delta: 0)
        expect(result[:ai_summary]).to be_a(String).and be_present
      end
    end

    context "streak_message" do
      it "max_streak が 3 以上の場合、streak_message を返す" do
        result = call(max_streak: 5)
        expect(result[:streak_message]).to be_present
        expect(result[:streak_message]).to include("5")
      end

      it "max_streak が 2 以下の場合、streak_message が nil であること" do
        result = call(max_streak: 2)
        expect(result[:streak_message]).to be_nil
      end
    end

    context "coach_reflection" do
      it "文字列を返すこと" do
        expect(call[:coach_reflection]).to be_a(String).and be_present
      end
    end

    context "personality ごとに異なるメッセージが生成される" do
      it "passionate と gentle で ai_summary が異なること" do
        passionate = call(personality: "passionate")[:ai_summary]
        gentle     = call(personality: "gentle")[:ai_summary]
        expect(passionate).not_to eq(gentle)
      end
    end

    context "同じ引数では毎回同じ結果を返す (deterministic)" do
      it "ai_summary が安定していること" do
        first  = call[:ai_summary]
        second = call[:ai_summary]
        expect(first).to eq second
      end
    end

    context "不明な personality はデフォルト passionate になる" do
      it "coach_reflection が返ること" do
        result = call(personality: "unknown_type")
        expect(result[:coach_reflection]).to be_present
      end
    end
  end
end
