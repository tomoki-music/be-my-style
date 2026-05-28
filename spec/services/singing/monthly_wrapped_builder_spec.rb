require "rails_helper"

RSpec.describe Singing::MonthlyWrappedBuilder do
  let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :passionate) }
  let(:year)  { 2026 }
  let(:month) { 5 }

  def completed_in_month(overall: 75, pitch: 70, rhythm: 70, expression: 70, day: 10)
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
    described_class.call(cust, year: year, month: month)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_wrapped: false を返すこと" do
        expect(described_class.call(nil, year: year, month: month).has_wrapped).to be false
      end

      it "diagnosis_count が 0 であること" do
        expect(described_class.call(nil, year: year, month: month).diagnosis_count).to eq 0
      end
    end

    context "対象月の診断が 0 件の場合" do
      it "has_wrapped: false を返すこと" do
        expect(call.has_wrapped).to be false
      end
    end

    context "対象月の診断が 1 件以上ある場合" do
      before { completed_in_month(overall: 70) }

      it "has_wrapped: true を返すこと" do
        expect(call.has_wrapped).to be true
      end

      it "diagnosis_count が正しいこと" do
        completed_in_month(overall: 75, day: 15)
        expect(call.diagnosis_count).to eq 2
      end

      it "active_days_count が正しいこと（同じ日は1カウント）" do
        completed_in_month(overall: 72, day: 10)
        expect(call.active_days_count).to eq 1
      end

      it "active_days_count が複数日を正しくカウントすること" do
        completed_in_month(overall: 72, day: 15)
        expect(call.active_days_count).to eq 2
      end

      it "monthly_xp が診断回数 × 50 の暫定値であること" do
        completed_in_month(overall: 72, day: 15)
        result = call
        expect(result.monthly_xp).to eq result.diagnosis_count * 50
      end
    end

    context "growth_type が入ること" do
      before { completed_in_month }

      it "growth_type が GrowthTypeAnalyzer::Result であること" do
        expect(call.growth_type).to be_a(Singing::GrowthTypeAnalyzer::Result)
      end
    end

    context "singer_rank が入ること" do
      before { completed_in_month }

      it "singer_rank が SingerRankService::Rank であること" do
        expect(call.singer_rank).to be_a(Singing::SingerRankService::Rank)
      end
    end

    context "診断が 2 件以上ある場合" do
      before do
        completed_in_month(overall: 55, pitch: 50, rhythm: 55, expression: 45, day: 1)
        completed_in_month(overall: 70, pitch: 65, rhythm: 70, expression: 68, day: 20)
      end

      it "most_improved_label が入ること" do
        expect(call.most_improved_label).to be_present
      end

      it "most_improved_delta が入ること" do
        expect(call.most_improved_delta).to be_a(Integer).and be > 0
      end
    end

    context "診断が 1 件のみの場合（比較なし）" do
      before { completed_in_month(overall: 70) }

      it "most_improved_label が nil であること" do
        expect(call.most_improved_label).to be_nil
      end

      it "most_improved_delta が nil であること" do
        expect(call.most_improved_delta).to be_nil
      end
    end

    context "wrapped_message / coach_reflection" do
      before { completed_in_month }

      it "wrapped_message が文字列を返すこと" do
        expect(call.wrapped_message).to be_a(String).and be_present
      end

      it "coach_reflection が文字列を返すこと" do
        expect(call.coach_reflection).to be_a(String).and be_present
      end
    end

    context "year / month フィールド" do
      before { completed_in_month }

      it "year が正しいこと" do
        expect(call.year).to eq year
      end

      it "month が正しいこと" do
        expect(call.month).to eq month
      end
    end
  end
end
