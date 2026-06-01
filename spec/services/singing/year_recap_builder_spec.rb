require "rails_helper"

RSpec.describe Singing::YearRecapBuilder do
  let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :passionate) }
  let(:year) { 2026 }

  def diagnosis_at(month, day, overall: 75, pitch: 70, rhythm: 70, expression: 70)
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
      it "has_recap: false を返す" do
        expect(described_class.call(nil, year: year).has_recap).to be false
      end
    end

    context "対象年の診断が 0 件の場合" do
      it "has_recap: false を返す" do
        expect(call.has_recap).to be false
      end

      it "diagnosis_count が 0 であること" do
        expect(call.diagnosis_count).to eq 0
      end
    end

    context "診断が 1 件以上ある場合" do
      before { diagnosis_at(1, 10) }

      it "has_recap: true を返す" do
        expect(call.has_recap).to be true
      end

      it "year が正しいこと" do
        expect(call.year).to eq year
      end

      it "diagnosis_count が正しいこと" do
        diagnosis_at(2, 15)
        expect(call.diagnosis_count).to eq 2
      end

      it "ai_summary が文字列を返すこと" do
        expect(call.ai_summary).to be_a(String).and be_present
      end

      it "coach_reflection が文字列を返すこと" do
        expect(call.coach_reflection).to be_a(String).and be_present
      end

      it "growth_type が GrowthTypeAnalyzer::Result であること" do
        expect(call.growth_type).to be_a(Singing::GrowthTypeAnalyzer::Result)
      end

      it "milestones が配列であること" do
        expect(call.milestones).to be_an(Array)
      end

      it "first_diagnosis_date が Date であること" do
        expect(call.first_diagnosis_date).to be_a(Date)
      end
    end

    context "複数診断がある場合" do
      before do
        diagnosis_at(1, 1,  overall: 55, pitch: 50, rhythm: 55, expression: 45)
        diagnosis_at(3, 15, overall: 72, pitch: 68, rhythm: 70, expression: 65)
        diagnosis_at(6, 20, overall: 80, pitch: 78, rhythm: 79, expression: 76)
      end

      it "most_improved_label が入ること" do
        expect(call.most_improved_label).to be_present
      end

      it "most_improved_delta が正の整数であること" do
        expect(call.most_improved_delta).to be_a(Integer).and be > 0
      end

      it "personal_best_score が入ること" do
        expect(call.personal_best_score).to be_present
      end

      it "max_streak が入ること" do
        expect(call.max_streak).to be_a(Integer)
      end
    end

    context "連続診断がある場合" do
      before do
        [1, 2, 3].each { |d| diagnosis_at(4, d) }
        diagnosis_at(4, 10)
      end

      it "streak_message が入ること" do
        expect(call.streak_message).to be_present
      end
    end
  end
end
