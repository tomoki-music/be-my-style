require "rails_helper"

RSpec.describe Singing::MonthlyGrowthComparisonAnalyzer do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:year)  { 2026 }
  let(:month) { 5 }

  def completed_in_month(overall:, pitch: 70, rhythm: 70, expression: 70, day: 10)
    ts = Time.zone.local(year, month, day)
    create(:singing_diagnosis, :completed,
           customer:         customer,
           overall_score:    overall,
           pitch_score:      pitch,
           rhythm_score:     rhythm,
           expression_score: expression,
           created_at:       ts,
           diagnosed_at:     ts)
  end

  def completed_outside_month(overall: 70)
    ts = Time.zone.local(year, month - 1, 15)
    create(:singing_diagnosis, :completed,
           customer:         customer,
           overall_score:    overall,
           created_at:       ts,
           diagnosed_at:     ts)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_comparison: false を返すこと" do
        result = described_class.call(nil, year: year, month: month)
        expect(result.has_comparison).to be false
      end

      it "diagnosis_count が 0 であること" do
        expect(described_class.call(nil, year: year, month: month).diagnosis_count).to eq 0
      end
    end

    context "対象月の診断 0 件の場合" do
      before { completed_outside_month }

      it "has_comparison: false を返すこと" do
        expect(described_class.call(customer, year: year, month: month).has_comparison).to be false
      end

      it "diagnosis_count が 0 であること" do
        expect(described_class.call(customer, year: year, month: month).diagnosis_count).to eq 0
      end
    end

    context "対象月の診断 1 件の場合" do
      before { completed_in_month(overall: 70) }

      it "has_comparison: false を返すこと" do
        expect(described_class.call(customer, year: year, month: month).has_comparison).to be false
      end

      it "diagnosis_count が 1 であること" do
        expect(described_class.call(customer, year: year, month: month).diagnosis_count).to eq 1
      end
    end

    context "対象月の診断 2 件の場合（初回 vs 最新）" do
      before do
        completed_in_month(overall: 55, pitch: 50, rhythm: 55, expression: 45, day: 1)
        completed_in_month(overall: 70, pitch: 65, rhythm: 70, expression: 68, day: 20)
      end

      it "has_comparison: true を返すこと" do
        expect(described_class.call(customer, year: year, month: month).has_comparison).to be true
      end

      it "diagnosis_count が 2 であること" do
        expect(described_class.call(customer, year: year, month: month).diagnosis_count).to eq 2
      end

      it "expression_score が最も伸びた項目として返ること" do
        result = described_class.call(customer, year: year, month: month)
        expect(result.most_improved_key).to eq :expression_score
        expect(result.most_improved_label).to eq "表現力"
        expect(result.most_improved_delta).to eq 23
      end
    end

    context "対象月の診断 6 件以上の場合（初回3件平均 vs 直近3件平均）" do
      before do
        completed_in_month(overall: 50, pitch: 50, rhythm: 50, expression: 50, day: 1)
        completed_in_month(overall: 52, pitch: 52, rhythm: 52, expression: 52, day: 3)
        completed_in_month(overall: 54, pitch: 54, rhythm: 54, expression: 54, day: 5)
        completed_in_month(overall: 70, pitch: 70, rhythm: 70, expression: 70, day: 15)
        completed_in_month(overall: 72, pitch: 72, rhythm: 72, expression: 72, day: 20)
        completed_in_month(overall: 74, pitch: 74, rhythm: 74, expression: 74, day: 25)
      end

      it "has_comparison: true を返すこと" do
        expect(described_class.call(customer, year: year, month: month).has_comparison).to be true
      end

      it "diagnosis_count が 6 であること" do
        expect(described_class.call(customer, year: year, month: month).diagnosis_count).to eq 6
      end

      it "first_scores が初回3件の平均であること" do
        result = described_class.call(customer, year: year, month: month)
        expect(result.first_scores[:overall_score]).to be_within(0.01).of(52.0)
      end

      it "recent_scores が直近3件の平均であること" do
        result = described_class.call(customer, year: year, month: month)
        expect(result.recent_scores[:overall_score]).to be_within(0.01).of(72.0)
      end
    end

    context "対象月外の診断は集計に含めないこと" do
      before do
        completed_outside_month(overall: 90)
        completed_in_month(overall: 60, day: 5)
        completed_in_month(overall: 70, day: 25)
      end

      it "対象月の診断のみ diagnosis_count に含まれること" do
        result = described_class.call(customer, year: year, month: month)
        expect(result.diagnosis_count).to eq 2
      end
    end

    context "score に nil が混在する場合" do
      before do
        ts1 = Time.zone.local(year, month, 1)
        create(:singing_diagnosis, :completed,
               customer:         customer,
               overall_score:    60,
               pitch_score:      nil,
               rhythm_score:     nil,
               expression_score: nil,
               created_at:       ts1,
               diagnosed_at:     ts1)
        completed_in_month(overall: 75, pitch: 70, rhythm: 72, expression: 80, day: 20)
      end

      it "クラッシュしないこと" do
        expect { described_class.call(customer, year: year, month: month) }.not_to raise_error
      end

      it "nil スコアは比較から除外されること" do
        result = described_class.call(customer, year: year, month: month)
        expect(result.deltas[:pitch_score]).to be_nil
      end
    end
  end
end
