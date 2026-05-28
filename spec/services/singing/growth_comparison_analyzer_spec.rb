require "rails_helper"

RSpec.describe Singing::GrowthComparisonAnalyzer do
  let(:customer) { create(:customer, domain_name: "singing") }

  def completed_with_scores(overall:, pitch: 70, rhythm: 70, expression: 70, created_at: Time.current)
    create(:singing_diagnosis, :completed,
           customer:         customer,
           overall_score:    overall,
           pitch_score:      pitch,
           rhythm_score:     rhythm,
           expression_score: expression,
           created_at:       created_at,
           diagnosed_at:     created_at)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_comparison: false を返すこと" do
        result = described_class.call(nil)
        expect(result.has_comparison).to be false
      end

      it "diagnosis_count が 0 であること" do
        expect(described_class.call(nil).diagnosis_count).to eq 0
      end

      it "weeks_since_start が 0 であること" do
        expect(described_class.call(nil).weeks_since_start).to eq 0
      end
    end

    context "診断 0 件の場合" do
      before { create(:singing_diagnosis, customer: customer, status: :queued) }

      it "has_comparison: false を返すこと" do
        expect(described_class.call(customer).has_comparison).to be false
      end

      it "diagnosis_count が 0 であること" do
        expect(described_class.call(customer).diagnosis_count).to eq 0
      end
    end

    context "診断 1 件の場合" do
      before { completed_with_scores(overall: 70) }

      it "has_comparison: false を返すこと" do
        expect(described_class.call(customer).has_comparison).to be false
      end

      it "diagnosis_count が 1 であること" do
        expect(described_class.call(customer).diagnosis_count).to eq 1
      end
    end

    context "診断 2 件の場合（初回 vs 最新）" do
      before do
        completed_with_scores(overall: 60, pitch: 55, rhythm: 60, expression: 50, created_at: 4.weeks.ago)
        completed_with_scores(overall: 75, pitch: 70, rhythm: 72, expression: 68, created_at: 1.day.ago)
      end

      it "has_comparison: true を返すこと" do
        expect(described_class.call(customer).has_comparison).to be true
      end

      it "diagnosis_count が 2 であること" do
        expect(described_class.call(customer).diagnosis_count).to eq 2
      end

      it "deltas を計算すること" do
        result = described_class.call(customer)
        expect(result.deltas[:overall_score]).to eq 15
        expect(result.deltas[:pitch_score]).to eq 15
        expect(result.deltas[:rhythm_score]).to eq 12
        expect(result.deltas[:expression_score]).to eq 18
      end

      it "most_improved_key が最大 delta を返すこと" do
        result = described_class.call(customer)
        expect(result.most_improved_key).to eq :expression_score
        expect(result.most_improved_label).to eq "表現力"
        expect(result.most_improved_delta).to eq 18
      end

      it "weeks_since_start が 0 以上であること" do
        expect(described_class.call(customer).weeks_since_start).to be >= 0
      end
    end

    context "診断 5 件の場合（初回 vs 最新）" do
      before do
        completed_with_scores(overall: 55, created_at: 10.weeks.ago)
        completed_with_scores(overall: 60, created_at: 7.weeks.ago)
        completed_with_scores(overall: 65, created_at: 5.weeks.ago)
        completed_with_scores(overall: 70, created_at: 3.weeks.ago)
        completed_with_scores(overall: 80, created_at: 1.week.ago)
      end

      it "has_comparison: true を返すこと" do
        expect(described_class.call(customer).has_comparison).to be true
      end

      it "初回 vs 最新で比較すること（average ではなく単件）" do
        result = described_class.call(customer)
        expect(result.first_scores[:overall_score]).to be_within(0.01).of(55.0)
        expect(result.recent_scores[:overall_score]).to be_within(0.01).of(80.0)
      end
    end

    context "診断 6 件以上の場合（初回3件平均 vs 直近3件平均）" do
      before do
        completed_with_scores(overall: 50, pitch: 50, rhythm: 50, expression: 50, created_at: 12.weeks.ago)
        completed_with_scores(overall: 52, pitch: 52, rhythm: 52, expression: 52, created_at: 10.weeks.ago)
        completed_with_scores(overall: 54, pitch: 54, rhythm: 54, expression: 54, created_at: 8.weeks.ago)
        completed_with_scores(overall: 70, pitch: 70, rhythm: 70, expression: 70, created_at: 4.weeks.ago)
        completed_with_scores(overall: 72, pitch: 72, rhythm: 72, expression: 72, created_at: 2.weeks.ago)
        completed_with_scores(overall: 74, pitch: 74, rhythm: 74, expression: 74, created_at: 1.week.ago)
      end

      it "has_comparison: true を返すこと" do
        expect(described_class.call(customer).has_comparison).to be true
      end

      it "diagnosis_count が 6 であること" do
        expect(described_class.call(customer).diagnosis_count).to eq 6
      end

      it "first_scores が初回3件の平均であること" do
        result = described_class.call(customer)
        expect(result.first_scores[:overall_score]).to be_within(0.01).of(52.0)
      end

      it "recent_scores が直近3件の平均であること" do
        result = described_class.call(customer)
        expect(result.recent_scores[:overall_score]).to be_within(0.01).of(72.0)
      end

      it "overall_score の delta が約 20 であること" do
        result = described_class.call(customer)
        expect(result.deltas[:overall_score]).to eq 20
      end
    end

    context "スコアに nil が混在する場合" do
      before do
        create(:singing_diagnosis, :completed,
               customer:         customer,
               overall_score:    60,
               pitch_score:      nil,
               rhythm_score:     nil,
               expression_score: nil,
               created_at:       4.weeks.ago,
               diagnosed_at:     4.weeks.ago)
        completed_with_scores(overall: 75, pitch: 70, rhythm: 72, expression: 80, created_at: 1.day.ago)
      end

      it "クラッシュしないこと" do
        expect { described_class.call(customer) }.not_to raise_error
      end

      it "nil スコアを平均から除外すること" do
        result = described_class.call(customer)
        expect(result.first_scores[:pitch_score]).to be_nil
      end

      it "nil デルタは nil であること" do
        result = described_class.call(customer)
        expect(result.deltas[:pitch_score]).to be_nil
      end
    end

    context "全スコアが下がった場合" do
      before do
        completed_with_scores(overall: 80, pitch: 80, rhythm: 80, expression: 80, created_at: 3.weeks.ago)
        completed_with_scores(overall: 70, pitch: 70, rhythm: 70, expression: 70, created_at: 1.day.ago)
      end

      it "most_improved_key が nil であること" do
        result = described_class.call(customer)
        expect(result.most_improved_key).to be_nil
        expect(result.most_improved_delta).to be_nil
      end

      it "has_comparison は true のままであること" do
        expect(described_class.call(customer).has_comparison).to be true
      end
    end
  end
end
