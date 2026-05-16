require "rails_helper"

RSpec.describe Singing::NextBadgeHintAggregator do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:earned_keys) { Set.new }

  def call(keys = earned_keys)
    described_class.call(customer, earned_badge_keys: keys)
  end

  def completed_diag(score: 75, created_at: Time.current)
    create(:singing_diagnosis, :completed, customer: customer,
           overall_score: score, created_at: created_at)
  end

  describe ".call" do
    context "進捗 > 0 のバッジがない場合" do
      it "nilを返すこと" do
        expect(call).to be_nil
      end
    end

    context "streak が進行中の場合" do
      it "Resultを返すこと" do
        3.times { |i| completed_diag(created_at: (2 - i).days.ago) }
        result = call
        expect(result).not_to be_nil
        expect(result.badge_key).to be_a(String)
        expect(result.progress_hint).to be_a(Singing::ProgressHintBuilder::ProgressHint)
      end

      it "streak系バッジが優遇されること（score系より優先）" do
        # score=40 にして first_score_90 ratio を低く保つ（40/90 ≈ 0.44）
        # streak 6日連続: ratio = 6/7 ≈ 0.857 → priority = 20+15+25.7 = 60.7
        # first_score_90:             ratio ≈ 0.44  → priority = 20+10+13.3 = 43.3
        6.times { |i| completed_diag(score: 40, created_at: (5 - i).days.ago) }
        result = call
        expect(result).not_to be_nil
        # streak_7 が選ばれること
        expect(%w[streak_7 streak_30]).to include(result.badge_key)
      end
    end

    context "is_close の判定" do
      it "progress_ratio >= 0.8 のとき is_close が true になること" do
        # streak_7: 6日連続 → ratio = 6/7 ≈ 0.857 >= 0.8
        6.times { |i| completed_diag(score: 40, created_at: (5 - i).days.ago) }
        result = call
        expect(result).not_to be_nil
        expect(result.is_close).to be true
      end

      it "progress_ratio < 0.8 のとき is_close が false になること" do
        # score=30: first_score_90 ratio = 30/90 ≈ 0.33 < 0.8
        # streak 1日: ratio = 1/7 ≈ 0.14 < 0.8
        # diagnosis_10: 1回 = 0.1 < 0.8
        # → いずれの hint も is_close にならない
        completed_diag(score: 30)
        result = call
        expect(result).not_to be_nil
        expect(result.is_close).to be false
      end
    end

    context "全バッジ獲得済みの場合" do
      it "nilを返すこと" do
        all_keys = Set.new(Singing::ProgressHintBuilder::HINT_BADGE_KEYS)
        expect(described_class.call(customer, earned_badge_keys: all_keys)).to be_nil
      end
    end

    context "他ユーザーの診断が存在する場合" do
      it "他ユーザーの診断は計算に含まれないこと" do
        other = create(:customer, domain_name: "singing")
        6.times { |i| create(:singing_diagnosis, :completed, customer: other, created_at: (5 - i).days.ago) }
        # 自分は診断なし → progress = 0
        expect(call).to be_nil
      end
    end
  end
end
