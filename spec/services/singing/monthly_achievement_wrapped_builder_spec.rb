require "rails_helper"

RSpec.describe Singing::MonthlyAchievementWrappedBuilder, type: :service do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:other)    { create(:customer, domain_name: "singing") }

  describe ".call" do
    subject(:result) { described_class.call(customer, "2026-05") }

    context "指定月にバッジがない場合" do
      it "empty? が true であること" do
        expect(result.empty?).to be true
      end

      it "total_count が 0 であること" do
        expect(result.total_count).to eq(0)
      end

      it "items が空配列であること" do
        expect(result.items).to be_empty
      end

      it "representative_badge が nil であること" do
        expect(result.representative_badge).to be_nil
      end

      it "month が正しく設定されること" do
        expect(result.month).to eq(Time.zone.local(2026, 5, 1).beginning_of_month)
      end
    end

    context "指定月にバッジがある場合" do
      let!(:badge_may1) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 5, 10, 0, 0))
      end
      let!(:badge_may2) do
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 5, 20, 10, 0, 0))
      end

      it "empty? が false であること" do
        expect(result.empty?).to be false
      end

      it "指定月のバッジのみ集計されること" do
        expect(result.total_count).to eq(2)
      end

      it "items に指定月のバッジが含まれること" do
        keys = result.items.map(&:badge_key)
        expect(keys).to include("first_diagnosis", "streak_7")
      end

      it "month_str が返ること" do
        expect(result.month_str).to eq("2026-05")
      end

      it "month_label が返ること" do
        expect(result.month_label).to eq("挑戦が形になった月")
      end
    end

    context "他月のバッジは含まれないこと" do
      let!(:badge_may) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 10, 10, 0, 0))
      end
      let!(:badge_apr) do
        create(:singing_achievement_badge, :personal_best, customer: customer,
               earned_at: Time.zone.local(2026, 4, 15, 10, 0, 0))
      end

      it "4月のバッジは含まれないこと" do
        keys = result.items.map(&:badge_key)
        expect(keys).to include("first_diagnosis")
        expect(keys).not_to include("personal_best")
      end

      it "total_count が 1 であること" do
        expect(result.total_count).to eq(1)
      end
    end

    context "他ユーザーのバッジは含まれないこと" do
      let!(:my_badge) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
      end
      let!(:other_badge) do
        create(:singing_achievement_badge, :streak_7, customer: other,
               earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
      end

      it "自分のバッジのみ含まれること" do
        expect(result.total_count).to eq(1)
        expect(result.items.map(&:badge_key)).to eq(["first_diagnosis"])
      end
    end

    context "rarity 別件数" do
      let!(:badge_common) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
      end
      let!(:badge_rare) do
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 5, 2, 10, 0, 0))
      end

      it "rarity 別件数が正しいこと" do
        expect(result.rarity_counts[:common]).to eq(1)
        expect(result.rarity_counts[:rare]).to eq(1)
        expect(result.rarity_counts[:epic]).to eq(0)
        expect(result.rarity_counts[:legendary]).to eq(0)
      end

      it "has_legendary が false であること" do
        expect(result.has_legendary).to be false
      end

      it "has_epic が false であること" do
        expect(result.has_epic).to be false
      end
    end

    context "representative badge の選択" do
      context "pinned があれば優先されること" do
        let!(:badge_common) do
          b = create(:singing_achievement_badge, :first_diagnosis, customer: customer,
                     earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
          b.pin!
          b
        end
        let!(:badge_rare) do
          create(:singing_achievement_badge, :streak_7, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 10, 10, 0, 0))
        end

        it "pinned バッジが representative になること" do
          expect(result.representative_badge.badge_key).to eq("first_diagnosis")
        end
      end

      context "pinned がなければ rarity 最高位が選ばれること" do
        let!(:badge_common) do
          create(:singing_achievement_badge, :first_diagnosis, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
        end
        let!(:badge_rare) do
          create(:singing_achievement_badge, :streak_7, customer: customer,
                 earned_at: Time.zone.local(2026, 5, 10, 10, 0, 0))
        end

        it "rare バッジが representative になること" do
          expect(result.representative_badge.badge_key).to eq("streak_7")
        end
      end
    end

    context "first_earned / last_earned" do
      let!(:badge_early) do
        create(:singing_achievement_badge, :first_diagnosis, customer: customer,
               earned_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
      end
      let!(:badge_late) do
        create(:singing_achievement_badge, :streak_7, customer: customer,
               earned_at: Time.zone.local(2026, 5, 25, 10, 0, 0))
      end

      it "first_earned が最初のバッジであること" do
        expect(result.first_earned.badge_key).to eq("first_diagnosis")
      end

      it "last_earned が最後のバッジであること" do
        expect(result.last_earned.badge_key).to eq("streak_7")
      end
    end

    context "不正な month 文字列" do
      subject(:result) { described_class.call(customer, "invalid") }

      it "empty? が true であること" do
        expect(result.empty?).to be true
      end

      it "落ちないこと" do
        expect { result }.not_to raise_error
      end
    end
  end
end
