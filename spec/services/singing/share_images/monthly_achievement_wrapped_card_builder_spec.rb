require "rails_helper"

RSpec.describe Singing::ShareImages::MonthlyAchievementWrappedCardBuilder, type: :service do
  subject(:card) { described_class.call(customer, "2026-05") }

  let(:customer) { create(:customer, domain_name: "singing") }

  context "customer が nil の場合" do
    subject(:card) { described_class.call(nil, "2026-05") }

    it "nil を返すこと" do
      expect(card).to be_nil
    end
  end

  context "指定月にバッジがない場合" do
    it "nil を返すこと（空状態では生成させない）" do
      expect(card).to be_nil
    end
  end

  context "指定月にバッジがある場合" do
    let!(:badge_common) do
      create(:singing_achievement_badge, :first_diagnosis, customer: customer,
             earned_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
    end
    let!(:badge_rare) do
      create(:singing_achievement_badge, :streak_7, customer: customer,
             earned_at: Time.zone.local(2026, 5, 20, 10, 0, 0))
    end

    it "Card を返すこと" do
      expect(card).to be_present
    end

    it "month_str が正しいこと" do
      expect(card.month_str).to eq("2026-05")
    end

    it "month_label が返ること" do
      expect(card.month_label).to be_present
    end

    it "total_count が正しいこと" do
      expect(card.total_count).to eq(2)
    end

    it "rarity_counts が正しいこと" do
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

    it "x_share_text に Achievement ハッシュタグが含まれること" do
      expect(card.x_share_text).to include("#Achievement")
    end

    it "x_share_text に月表示が含まれること" do
      expect(card.x_share_text).to include("2026年5月")
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
             earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    end
    let!(:badge_last) do
      create(:singing_achievement_badge, :streak_7, customer: customer,
             earned_at: Time.zone.local(2026, 5, 25, 10, 0, 0))
    end

    it "growth_story に first と last が含まれること" do
      expect(card.growth_story).to include("から")
      expect(card.growth_story).to include("まで")
    end
  end
end
