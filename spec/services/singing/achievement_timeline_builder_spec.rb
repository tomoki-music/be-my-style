require "rails_helper"

RSpec.describe Singing::AchievementTimelineBuilder, type: :service do
  let(:customer) { create(:customer, domain_name: "singing") }

  describe ".call" do
    subject(:groups) { described_class.call(customer) }

    context "獲得済みバッジがない場合" do
      it "空の配列を返すこと" do
        expect(groups).to be_empty
      end
    end

    context "獲得済みバッジがある場合" do
      let!(:badge_may) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 10, 12, 0, 0))
      end
      let!(:badge_may2) do
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 5, 20, 12, 0, 0))
      end
      let!(:badge_apr) do
        create(:singing_achievement_badge, :personal_best, customer: customer,
               earned_at: Time.zone.local(2026, 4, 15, 12, 0, 0))
      end

      it "月ごとにグループ化されること" do
        expect(groups.size).to eq(2)
      end

      it "earned_at desc 順（新しい月が先）になること" do
        expect(groups.first.month.month).to eq(5)
        expect(groups.last.month.month).to eq(4)
      end

      it "同月の複数バッジがまとまること" do
        may_group = groups.find { |g| g.month.month == 5 }
        expect(may_group.items.size).to eq(2)
      end

      it "グループ内のバッジが earned_at desc 順であること" do
        may_group = groups.find { |g| g.month.month == 5 }
        dates = may_group.items.map(&:earned_at)
        expect(dates).to eq(dates.sort.reverse)
      end

      it "TimelineMonthGroup が month / label / items を持つこと" do
        group = groups.first
        expect(group.month).to be_a(Time)
        expect(group.label).to be_a(String)
        expect(group.label).not_to be_empty
        expect(group.items).to be_an(Array)
      end

      it "TimelineItem が必要なメソッドを持つこと" do
        item = groups.first.items.first
        expect(item.badge_key).to be_present
        expect(item.label).to be_present
        expect(item.emoji).to be_present
        expect(item.rarity).to be_present
        expect(item.earned_at).to be_a(Time)
        expect(item.badge_id).to eq(item.customer_achievement_badge.id)
      end

      it "pinned? が正しく返ること" do
        badge_may.pin!
        groups_fresh = described_class.call(customer)
        may_group = groups_fresh.find { |g| g.month.month == 5 }
        pinned_item = may_group.items.find { |i| i.badge_key == "first_diagnosis" }
        expect(pinned_item.pinned?).to be true
      end
    end

    context "月ラベル" do
      it "5月のラベルが正しいこと" do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 1))
        group = described_class.call(customer).first
        expect(group.label).to eq("挑戦が形になった月")
      end

      it "全12か月のラベルが定義されていること" do
        expect(described_class::MONTH_LABELS.keys).to match_array((1..12).to_a)
      end
    end

    context "他ユーザーのバッジは対象外" do
      let(:other) { create(:customer, domain_name: "singing") }

      it "other のバッジは含まれないこと" do
        create(:singing_achievement_badge, :first_diagnosis, customer: other,
               earned_at: Time.zone.local(2026, 5, 1))
        expect(described_class.call(customer)).to be_empty
      end
    end
  end
end
