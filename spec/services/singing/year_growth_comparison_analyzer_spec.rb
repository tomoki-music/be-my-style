require "rails_helper"

RSpec.describe Singing::YearGrowthComparisonAnalyzer do
  let(:customer) { create(:customer, domain_name: "singing") }
  let(:year) { 2026 }

  def diagnosis_at(day, month: 1, overall: 75, pitch: 70, rhythm: 70, expression: 70)
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

  def call(cust = customer)
    described_class.call(cust, year: year)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_comparison: false, diagnosis_count: 0 を返す" do
        result = described_class.call(nil, year: year)
        expect(result.has_comparison).to be false
        expect(result.diagnosis_count).to eq 0
      end
    end

    context "対象年の診断が 0 件の場合" do
      it "has_comparison: false を返す" do
        expect(call.has_comparison).to be false
        expect(call.diagnosis_count).to eq 0
        expect(call.milestones).to be_empty
      end
    end

    context "診断が 1 件の場合" do
      before { diagnosis_at(10) }

      it "has_comparison: false を返す" do
        expect(call.has_comparison).to be false
      end

      it "diagnosis_count が 1 であること" do
        expect(call.diagnosis_count).to eq 1
      end

      it "first_diagnosis_date が入ること" do
        expect(call.first_diagnosis_date).to eq Date.new(year, 1, 10)
      end

      it "milestones に first_diagnosis が含まれること" do
        m = call.milestones
        expect(m.map(&:type)).to include(:first_diagnosis)
      end
    end

    context "診断が 2 件以上の場合" do
      before do
        diagnosis_at(1,  overall: 55, pitch: 50, rhythm: 55, expression: 45)
        diagnosis_at(20, overall: 72, pitch: 68, rhythm: 70, expression: 65)
      end

      it "has_comparison: true を返す" do
        expect(call.has_comparison).to be true
      end

      it "most_improved_label が入ること" do
        expect(call.most_improved_label).to be_present
      end

      it "most_improved_delta が正の整数であること" do
        expect(call.most_improved_delta).to be_a(Integer).and be > 0
      end
    end

    context "max_streak の計算" do
      it "連続した日付の最長ストリークを返す" do
        diagnosis_at(1)
        diagnosis_at(2)
        diagnosis_at(3)
        diagnosis_at(5)
        expect(call.max_streak).to eq 3
      end

      it "連続なしの場合は 1 を返す" do
        diagnosis_at(1)
        diagnosis_at(10)
        expect(call.max_streak).to eq 1
      end
    end

    context "personal_best_score / personal_best_date" do
      before do
        diagnosis_at(5,  overall: 60)
        diagnosis_at(15, overall: 85)
        diagnosis_at(25, overall: 70)
      end

      it "personal_best_score が最高スコアであること" do
        expect(call.personal_best_score).to eq 85
      end

      it "personal_best_date が最高スコアの日付であること" do
        expect(call.personal_best_date).to eq Date.new(year, 1, 15)
      end
    end

    context "most_active_month" do
      before do
        3.times { |i| diagnosis_at(i + 1, month: 3) }
        1.times { |i| diagnosis_at(i + 1, month: 5) }
      end

      it "最も診断回数が多い月番号を返す" do
        expect(call.most_active_month).to eq 3
      end

      it "most_active_month_count が正しいこと" do
        expect(call.most_active_month_count).to eq 3
      end

      it "most_active_month_label が '3月' であること" do
        expect(call.most_active_month_label).to eq "3月"
      end
    end

    context "milestones" do
      before do
        diagnosis_at(5,  overall: 60)
        diagnosis_at(15, overall: 82)
      end

      it "first_diagnosis と first_80 と personal_best を含む" do
        types = call.milestones.map(&:type)
        expect(types).to include(:first_diagnosis)
        expect(types).to include(:first_80)
        expect(types).to include(:personal_best)
      end
    end

    context "overall_score が nil の診断は除外される" do
      it "has_comparison: false を返す" do
        ts = Time.zone.local(year, 1, 10)
        create(:singing_diagnosis, :completed,
               customer:      customer,
               overall_score: nil,
               created_at:    ts,
               diagnosed_at:  ts)
        expect(call.diagnosis_count).to eq 0
      end
    end

    context "他年の診断は含まれない" do
      it "対象年以外の診断を除外する" do
        ts = Time.zone.local(year - 1, 6, 1)
        create(:singing_diagnosis, :completed,
               customer:      customer,
               overall_score: 70,
               created_at:    ts,
               diagnosed_at:  ts)
        expect(call.diagnosis_count).to eq 0
      end
    end
  end
end
