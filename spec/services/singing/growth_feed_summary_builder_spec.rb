require "rails_helper"

RSpec.describe Singing::GrowthFeedSummaryBuilder do
  describe ".call" do
    it "emptyでもSummaryを返す" do
      summary = described_class.call

      expect(summary).to be_a(described_class::Summary)
      expect(summary.weekly_singer_count).to eq(0)
      expect(summary.weekly_first_diagnosis_count).to eq(0)
      expect(summary.weekly_cheer_count).to eq(0)
      expect(summary.weekly_challenge_completion_count).to eq(0)
      expect(summary.growth_type_highlights).to eq([])
    end

    it "今週の歌った人数、初診断、応援数を集計する" do
      singer = create(:customer, domain_name: "singing")
      supporter = create(:customer, domain_name: "singing")
      create(:singing_diagnosis, :completed, customer: singer, overall_score: 70, created_at: Time.current)
      create(:singing_cheer_reaction, customer: supporter, target_customer: singer, created_at: Time.current)

      summary = described_class.call

      expect(summary.weekly_singer_count).to eq(1)
      expect(summary.weekly_first_diagnosis_count).to eq(1)
      expect(summary.weekly_cheer_count).to eq(1)
      expect(summary.growth_type_highlights.first).to be_a(described_class::GrowthTypeHighlight)
    end

    it "週5回診断をチャレンジ達成として数える" do
      singer = create(:customer, domain_name: "singing")
      5.times do |i|
        create(:singing_diagnosis, :completed, customer: singer, overall_score: 70 + i, created_at: i.hours.ago)
      end

      summary = described_class.call

      expect(summary.weekly_challenge_completion_count).to be >= 1
    end

    it "nil安全" do
      expect { described_class.call }.not_to raise_error
    end
  end
end
