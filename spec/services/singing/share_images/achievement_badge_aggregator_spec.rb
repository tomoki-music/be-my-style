require "rails_helper"

RSpec.describe Singing::ShareImages::AchievementBadgeAggregator, type: :service do
  subject(:stats) { described_class.call(customer) }

  let(:customer) { create(:customer, domain_name: "singing") }

  context "when customer is nil" do
    subject(:stats) { described_class.call(nil) }

    it "returns nil" do
      expect(stats).to be_nil
    end
  end

  context "when customer has no badges" do
    it "returns stats with has_badges: false" do
      expect(stats.has_badges).to be false
    end

    it "returns empty earned_badges" do
      expect(stats.earned_badges).to be_empty
    end

    it "returns total_count: 0" do
      expect(stats.total_count).to eq(0)
    end

    it "returns newest_badge: nil" do
      expect(stats.newest_badge).to be_nil
    end
  end

  context "when customer has badges" do
    let!(:old_badge) { create(:singing_achievement_badge, customer: customer, badge_key: "first_diagnosis", earned_at: 2.days.ago) }
    let!(:new_badge) { create(:singing_achievement_badge, customer: customer, badge_key: "personal_best",  earned_at: 1.day.ago) }

    it "returns has_badges: true" do
      expect(stats.has_badges).to be true
    end

    it "returns newest_badge as the most recently earned" do
      expect(stats.newest_badge).to eq(new_badge)
    end

    it "returns total_count" do
      expect(stats.total_count).to eq(2)
    end

    it "returns earned_badges ordered by earned_at desc" do
      expect(stats.earned_badges.first).to eq(new_badge)
    end
  end

  context "when customer has more than 5 badges" do
    # 重複しない6種を明示指定する
    let(:all_keys) { %w[first_diagnosis personal_best streak_7 first_score_90 first_ranking growth_10] }

    before do
      all_keys.each_with_index do |key, i|
        create(:singing_achievement_badge, customer: customer, badge_key: key, earned_at: i.days.ago)
      end
    end

    it "returns at most 5 earned_badges" do
      expect(stats.earned_badges.size).to eq(5)
    end

    it "returns correct total_count" do
      expect(stats.total_count).to eq(6)
    end
  end
end
