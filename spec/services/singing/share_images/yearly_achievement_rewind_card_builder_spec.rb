require "rails_helper"

RSpec.describe Singing::ShareImages::YearlyAchievementRewindCardBuilder, type: :service do
  subject(:card) { described_class.call(customer, year: 2026) }

  let(:customer) { create(:customer, domain_name: "singing") }

  context "customer が nil の場合" do
    subject(:card) { described_class.call(nil, year: 2026) }

    it "nil を返すこと" do
      expect(card).to be_nil
    end
  end

  context "指定年にバッジがない場合" do
    it "nil を返すこと" do
      expect(card).to be_nil
    end
  end

  context "指定年にバッジがある場合" do
    let!(:badge_common) do
      create(:singing_achievement_badge, :first_diagnosis, customer: customer,
             earned_at: Time.zone.local(2026, 3, 5, 10, 0, 0))
    end
    let!(:badge_rare) do
      create(:singing_achievement_badge, :streak_7, customer: customer,
             earned_at: Time.zone.local(2026, 7, 20, 10, 0, 0))
    end

    it "Card を返すこと" do
      expect(card).to be_present
    end

    it "year が正しいこと" do
      expect(card.year).to eq(2026)
    end

    it "total_count が正しいこと" do
      expect(card.total_count).to eq(2)
    end

    it "rarity_counts が返ること" do
      expect(card.rarity_counts[:common]).to eq(1)
      expect(card.rarity_counts[:rare]).to eq(1)
    end

    it "representative_badge が返ること" do
      expect(card.representative_badge).to be_present
    end

    it "headline が返ること" do
      expect(card.headline).to be_present
    end

    it "growth_story が返ること" do
      expect(card.growth_story).to be_present
    end

    it "x_share_text が返ること" do
      expect(card.x_share_text).to be_present
    end

    it "x_share_text に AchievementRewind ハッシュタグが含まれること" do
      expect(card.x_share_text).to include("#AchievementRewind")
    end

    it "x_share_text に年が含まれること" do
      expect(card.x_share_text).to include("2026年")
    end

    it "milestone_count が 0 であること（legendary/epic なし）" do
      expect(card.milestone_count).to eq(0)
    end
  end

  context "epic バッジがある場合" do
    let!(:badge_epic) do
      create(:singing_achievement_badge, :streak_30, customer: customer,
             earned_at: Time.zone.local(2026, 5, 10, 10, 0, 0))
    end

    it "has_epic が true になること" do
      expect(card.has_epic).to be true
    end

    it "headline に Epic が含まれること" do
      expect(card.headline).to include("Epic")
    end

    it "milestone_count が 1 になること" do
      expect(card.milestone_count).to eq(1)
    end
  end

  context "growth_story: バッジが1件の場合" do
    let!(:badge) do
      create(:singing_achievement_badge, :first_diagnosis, customer: customer,
             earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    end

    it "growth_story が present であること" do
      expect(card.growth_story).to be_present
    end
  end

  context "growth_story: バッジが2件以上の場合" do
    let!(:badge_first) do
      create(:singing_achievement_badge, :first_diagnosis, customer: customer,
             earned_at: Time.zone.local(2026, 1, 1, 10, 0, 0))
    end
    let!(:badge_last) do
      create(:singing_achievement_badge, :streak_7, customer: customer,
             earned_at: Time.zone.local(2026, 11, 25, 10, 0, 0))
    end

    it "growth_story に first と last が含まれること" do
      expect(card.growth_story).to include("から")
      expect(card.growth_story).to include("まで")
    end
  end
end
