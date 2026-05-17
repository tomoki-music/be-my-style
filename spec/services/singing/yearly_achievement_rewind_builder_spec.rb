require "rails_helper"

RSpec.describe Singing::YearlyAchievementRewindBuilder, type: :service do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:other)    { create(:customer, domain_name: "singing") }

  describe ".call" do
    subject(:result) { described_class.call(customer, year: 2026) }

    context "指定年にバッジがない場合" do
      it "empty? が true であること" do
        expect(result.empty?).to be true
      end

      it "total_count が 0 であること" do
        expect(result.total_count).to eq(0)
      end

      it "items が空であること" do
        expect(result.items).to be_empty
      end

      it "monthly_highlights が空であること" do
        expect(result.monthly_highlights).to be_empty
      end

      it "year が正しく設定されること" do
        expect(result.year).to eq(2026)
      end
    end

    context "指定年にバッジがある場合" do
      let!(:badge_jan) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 1, 10, 10, 0, 0))
      end
      let!(:badge_may) do
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 5, 20, 10, 0, 0))
      end

      it "empty? が false であること" do
        expect(result.empty?).to be false
      end

      it "total_count が正しいこと" do
        expect(result.total_count).to eq(2)
      end

      it "items にバッジが含まれること" do
        keys = result.items.map(&:badge_key)
        expect(keys).to include("first_diagnosis", "streak_7")
      end

      it "year が正しいこと" do
        expect(result.year).to eq(2026)
      end

      it "rarity_counts が正しいこと" do
        expect(result.rarity_counts[:common]).to eq(1)
        expect(result.rarity_counts[:rare]).to eq(1)
        expect(result.rarity_counts[:legendary]).to eq(0)
      end

      it "has_legendary が false であること" do
        expect(result.has_legendary).to be false
      end

      it "has_epic が false であること" do
        expect(result.has_epic).to be false
      end

      it "representative_badge が返ること" do
        expect(result.representative_badge).to be_present
      end

      it "monthly_highlights が2ヶ月分あること" do
        expect(result.monthly_highlights.size).to eq(2)
      end

      it "monthly_highlights が earned_at 昇順であること" do
        months = result.monthly_highlights.map { |m| m.month.month }
        expect(months).to eq([1, 5])
      end

      it "first_earned が最初のバッジであること" do
        expect(result.first_earned.badge_key).to eq("first_diagnosis")
      end

      it "last_earned が最後のバッジであること" do
        expect(result.last_earned.badge_key).to eq("streak_7")
      end

      it "milestone_count が 0 であること（legendary/epic なし）" do
        expect(result.milestone_count).to eq(0)
      end
    end

    context "他年のバッジは含まれないこと" do
      let!(:badge_2026) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 3, 1, 10, 0, 0))
      end
      let!(:badge_2025) do
        create(:singing_achievement_badge, :personal_best, customer: customer,
               earned_at: Time.zone.local(2025, 12, 31, 10, 0, 0))
      end

      it "2026年のバッジのみ集計されること" do
        expect(result.total_count).to eq(1)
        expect(result.items.map(&:badge_key)).to eq(["first_diagnosis"])
      end
    end

    context "他ユーザーのバッジは含まれないこと" do
      let!(:my_badge) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
      end
      let!(:other_badge) do
        create(:singing_achievement_badge, :streak_7, customer: other,
               earned_at: Time.zone.local(2026, 5, 2, 10, 0, 0))
      end

      it "自分のバッジのみ含まれること" do
        expect(result.total_count).to eq(1)
        expect(result.items.map(&:badge_key)).to eq(["first_diagnosis"])
      end
    end

    context "epic バッジがある場合" do
      let!(:badge_epic) do
        create(:singing_achievement_badge, :streak_30, customer: customer,
               earned_at: Time.zone.local(2026, 6, 30, 10, 0, 0))
      end

      it "has_epic が true になること" do
        expect(result.has_epic).to be true
      end

      it "milestone_count が 1 になること" do
        expect(result.milestone_count).to eq(1)
      end
    end

    context "monthly_highlights が DB 再クエリなしで正しいこと" do
      let!(:badge_jan) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 1, 5, 10, 0, 0))
      end
      let!(:badge_jan2) do
        create(:singing_achievement_badge, :personal_best, customer: customer,
               earned_at: Time.zone.local(2026, 1, 15, 10, 0, 0))
      end
      let!(:badge_mar) do
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 3, 10, 10, 0, 0))
      end

      it "1月のhighlightが2件であること" do
        jan_highlight = result.monthly_highlights.find { |m| m.month.month == 1 }
        expect(jan_highlight).to be_present
        expect(jan_highlight.total_count).to eq(2)
      end

      it "3月のhighlightが1件であること" do
        mar_highlight = result.monthly_highlights.find { |m| m.month.month == 3 }
        expect(mar_highlight).to be_present
        expect(mar_highlight.total_count).to eq(1)
      end
    end

    context "customer が nil の場合" do
      subject(:result) { described_class.call(nil, year: 2026) }

      it "empty? が true であること" do
        expect(result.empty?).to be true
      end

      it "落ちないこと" do
        expect { result }.not_to raise_error
      end
    end
  end
end
