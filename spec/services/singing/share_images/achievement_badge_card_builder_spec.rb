require "rails_helper"

RSpec.describe Singing::ShareImages::AchievementBadgeCardBuilder, type: :service do
  subject(:card) { described_class.call(customer) }

  let(:customer) { create(:customer, domain_name: "singing") }

  context "when customer is nil" do
    subject(:card) { described_class.call(nil) }

    it "returns nil" do
      expect(card).to be_nil
    end
  end

  context "when customer has no badges" do
    it "returns an empty card (not nil)" do
      expect(card).to be_present
    end

    it "sets fallback headline" do
      expect(card.headline).to be_present
    end

    it "sets fallback emoji" do
      expect(card.emoji).to eq("🎤")
    end

    it "has nil badge_key" do
      expect(card.badge_key).to be_nil
    end

    it "has x_share_text" do
      expect(card.x_share_text).to be_present
    end
  end

  context "when customer has badges" do
    let!(:badge) do
      create(:singing_achievement_badge, :first_score_90,
             customer: customer,
             earned_at: 1.day.ago,
             metadata: {
               schema_version:  1,
               badge_key:       "first_score_90",
               badge_label:     "Score 90 Club",
               earned_at_label: "2024年5月15日",
               diagnosis_count: 5,
               overall_score:   91
             })
    end

    it "returns the newest badge data" do
      expect(card.badge_key).to eq("first_score_90")
    end

    it "sets emoji from BADGE_DEFINITIONS" do
      expect(card.emoji).to eq("⭐")
    end

    it "sets badge_label" do
      expect(card.badge_label).to eq("Score 90 Club")
    end

    it "sets rarity from BADGE_DEFINITIONS" do
      expect(card.rarity).to eq(:rare)
    end

    it "sets rarity_label" do
      expect(card.rarity_label).to eq("RARE")
    end

    it "sets earned_at_label from metadata" do
      expect(card.earned_at_label).to eq("2024年5月15日")
    end

    it "sets headline with score info" do
      expect(card.headline).to include("91点")
    end

    it "sets x_share_text" do
      expect(card.x_share_text).to include("#BeMyStyle")
    end

    context "personal_best badge" do
      let!(:badge) do
        create(:singing_achievement_badge, :personal_best,
               customer: customer,
               earned_at: Time.current,
               metadata: {
                 schema_version:     1,
                 badge_key:          "personal_best",
                 badge_label:        "Personal Best",
                 earned_at_label:    "2024年5月20日",
                 diagnosis_count:    10,
                 current_best_score: 88,
                 previous_best_score: 82,
                 score_delta:        6
               })
      end

      it "includes score delta in headline" do
        expect(card.headline).to include("88点")
        expect(card.headline).to include("6点")
      end
    end

    context "streak_7 badge" do
      let!(:badge) do
        create(:singing_achievement_badge, :streak_7,
               customer: customer,
               earned_at: Time.current,
               metadata: {
                 schema_version: 1, badge_key: "streak_7",
                 badge_label: "7 Day Streak", earned_at_label: "2024年5月7日",
                 diagnosis_count: 7, streak_days: 7
               })
      end

      it "returns streak headline" do
        expect(card.headline).to include("7日間")
      end
    end

    context "subline" do
      let!(:badge) do
        create(:singing_achievement_badge, :first_diagnosis,
               customer: customer,
               earned_at: Time.current,
               metadata: {
                 schema_version: 1, badge_key: "first_diagnosis",
                 badge_label: "First Note", earned_at_label: "2024年5月1日",
                 diagnosis_count: 5
               })
      end

      it "includes diagnosis_count in subline" do
        expect(card.subline).to include("5回")
      end
    end
  end
end
