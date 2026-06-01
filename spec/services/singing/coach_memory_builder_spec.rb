require "rails_helper"

RSpec.describe Singing::CoachMemoryBuilder do
  let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :passionate) }

  def diagnosis_at(days_ago, overall: 75, pitch: 70, rhythm: 70, expression: 70)
    ts = days_ago.days.ago
    create(:singing_diagnosis, :completed,
           customer:         customer,
           overall_score:    overall,
           pitch_score:      pitch,
           rhythm_score:     rhythm,
           expression_score: expression,
           created_at:       ts,
           diagnosed_at:     ts)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_memory: false を返す" do
        result = described_class.call(nil)
        expect(result.has_memory).to be false
      end

      it "diagnosis_count が 0 であること" do
        expect(described_class.call(nil).diagnosis_count).to eq 0
      end
    end

    context "完了済み診断が 0 件の場合" do
      it "has_memory: false を返す" do
        expect(described_class.call(customer).has_memory).to be false
      end
    end

    context "診断が 1 件ある場合" do
      before { diagnosis_at(7) }

      it "has_memory: true を返す" do
        expect(described_class.call(customer).has_memory).to be true
      end

      it "diagnosis_count が 1 であること" do
        expect(described_class.call(customer).diagnosis_count).to eq 1
      end

      it "first_diagnosis_at が Date であること" do
        expect(described_class.call(customer).first_diagnosis_at).to be_a Date
      end

      it "growth_type が返ること" do
        expect(described_class.call(customer).growth_type).not_to be_nil
      end

      it "recent_trend_label が nil であること (1件では比較不可)" do
        expect(described_class.call(customer).recent_trend_label).to be_nil
      end
    end

    context "診断が複数ある場合" do
      before do
        diagnosis_at(30, pitch: 60, rhythm: 60, expression: 60, overall: 60)
        diagnosis_at(14, pitch: 70, rhythm: 60, expression: 60, overall: 65)
        diagnosis_at(1,  pitch: 75, rhythm: 65, expression: 68, overall: 70)
      end

      it "diagnosis_count が正しいこと" do
        expect(described_class.call(customer).diagnosis_count).to eq 3
      end

      it "weeks_since_start が 0 以上であること" do
        expect(described_class.call(customer).weeks_since_start).to be >= 0
      end

      it "recent_trend_label が文字列を返すこと" do
        result = described_class.call(customer)
        expect(result.recent_trend_label).to be_a(String).or be_nil
      end

      it "max_streak が 0 以上であること" do
        expect(described_class.call(customer).max_streak).to be >= 0
      end
    end
  end
end
