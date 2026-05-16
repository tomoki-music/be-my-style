require "rails_helper"

RSpec.describe SingingAchievementBadge, type: :model do
  describe "associations" do
    it "belongs to customer" do
      badge = build(:singing_achievement_badge)
      expect(badge.customer).to be_present
    end

    it "belongs_to singing_diagnosis optionally" do
      badge = build(:singing_achievement_badge, singing_diagnosis: nil)
      expect(badge).to be_valid
    end
  end

  describe "validations" do
    it "requires badge_key" do
      badge = build(:singing_achievement_badge, badge_key: nil)
      expect(badge).not_to be_valid
      expect(badge.errors[:badge_key]).to be_present
    end

    it "requires earned_at" do
      badge = build(:singing_achievement_badge, earned_at: nil)
      expect(badge).not_to be_valid
      expect(badge.errors[:earned_at]).to be_present
    end

    it "is valid with a known badge_key" do
      badge = build(:singing_achievement_badge, badge_key: "first_diagnosis")
      expect(badge).to be_valid
    end

    it "is invalid with an unknown badge_key" do
      badge = build(:singing_achievement_badge, badge_key: "unknown_badge")
      expect(badge).not_to be_valid
      expect(badge.errors[:badge_key]).to be_present
    end
  end

  describe "unique index" do
    let(:customer) { create(:customer, domain_name: "singing") }

    it "prevents duplicate badge_key for the same customer" do
      create(:singing_achievement_badge, customer: customer, badge_key: "first_diagnosis")
      duplicate = build(:singing_achievement_badge, customer: customer, badge_key: "first_diagnosis")
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows same badge_key for different customers" do
      customer2 = create(:customer, domain_name: "singing")
      create(:singing_achievement_badge, customer: customer, badge_key: "first_diagnosis")
      expect {
        create(:singing_achievement_badge, customer: customer2, badge_key: "first_diagnosis")
      }.not_to raise_error
    end
  end

  describe "BADGE_DEFINITIONS" do
    it "includes all MVP badge keys" do
      expect(described_class::MVP_BADGE_KEYS).to include(
        "first_diagnosis", "personal_best", "streak_7", "streak_30",
        "first_score_90", "first_ranking", "diagnosis_10", "growth_10"
      )
    end

    it "has required fields for every badge" do
      described_class::BADGE_DEFINITIONS.each do |key, defn|
        %i[label short_label emoji rarity category plan share_image_plan description locked_description share_text].each do |field|
          expect(defn[field]).to be_present, "#{key} is missing :#{field}"
        end
      end
    end

    it "has valid rarity for every badge" do
      described_class::BADGE_DEFINITIONS.each do |key, defn|
        expect(described_class::RARITIES).to include(defn[:rarity]), "#{key} has invalid rarity: #{defn[:rarity]}"
      end
    end

    it "has valid category for every badge" do
      described_class::BADGE_DEFINITIONS.each do |key, defn|
        expect(described_class::CATEGORIES).to include(defn[:category]), "#{key} has invalid category: #{defn[:category]}"
      end
    end
  end

  describe "FEATURE_RULES" do
    it "includes singing_achievement_badge_share_image for core and premium" do
      expect(Customer::FEATURE_RULES[:singing_achievement_badge_share_image]).to include("core", "premium")
    end

    it "does not include free or light" do
      expect(Customer::FEATURE_RULES[:singing_achievement_badge_share_image]).not_to include("free", "light")
    end
  end

  describe "scopes" do
    let(:customer) { create(:customer, domain_name: "singing") }

    describe ".earned" do
      it "orders by earned_at desc" do
        old_badge = create(:singing_achievement_badge, customer: customer, badge_key: "first_diagnosis", earned_at: 2.days.ago)
        new_badge = create(:singing_achievement_badge, customer: customer, badge_key: "personal_best",  earned_at: 1.day.ago)
        expect(customer.singing_achievement_badges.earned.first).to eq(new_badge)
        expect(customer.singing_achievement_badges.earned.last).to eq(old_badge)
      end
    end
  end

  describe "delegate methods" do
    let(:badge) { build(:singing_achievement_badge, badge_key: "first_diagnosis") }

    it "returns label from BADGE_DEFINITIONS" do
      expect(badge.label).to eq("First Note")
    end

    it "returns emoji from BADGE_DEFINITIONS" do
      expect(badge.emoji).to eq("🎤")
    end

    it "returns rarity from BADGE_DEFINITIONS" do
      expect(badge.rarity).to eq(:common)
    end
  end
end
