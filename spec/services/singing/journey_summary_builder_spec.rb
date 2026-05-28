require "rails_helper"

RSpec.describe Singing::JourneySummaryBuilder do
  let(:customer) { create(:customer, domain_name: "singing") }

  def completed_with_score(overall:, pitch: 70, rhythm: 70, expression: 70, created_at: Time.current)
    create(:singing_diagnosis, :completed,
           customer: customer,
           overall_score: overall,
           pitch_score: pitch,
           rhythm_score: rhythm,
           expression_score: expression,
           created_at: created_at,
           diagnosed_at: created_at)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_diagnoses: false の空 Result を返すこと" do
        result = described_class.call(nil)
        expect(result.has_diagnoses).to be false
        expect(result.diagnosis_count).to eq 0
      end
    end

    context "完了済み診断が 0 件の場合" do
      before { create(:singing_diagnosis, customer: customer, status: :queued) }

      it "has_diagnoses: false を返すこと" do
        expect(described_class.call(customer).has_diagnoses).to be false
      end

      it "diagnosis_count が 0 であること" do
        expect(described_class.call(customer).diagnosis_count).to eq 0
      end
    end

    context "overall_score が nil の診断のみの場合" do
      before do
        create(:singing_diagnosis, :completed, customer: customer, overall_score: nil)
      end

      it "has_diagnoses: false を返すこと" do
        expect(described_class.call(customer).has_diagnoses).to be false
      end
    end

    context "完了済み診断が 1 件ある場合" do
      before { completed_with_score(overall: 75, pitch: 72, rhythm: 76, expression: 73) }

      it "has_diagnoses: true を返すこと" do
        expect(described_class.call(customer).has_diagnoses).to be true
      end

      it "diagnosis_count が 1 であること" do
        expect(described_class.call(customer).diagnosis_count).to eq 1
      end

      it "best_score が返ること" do
        expect(described_class.call(customer).best_score).to eq 75
      end

      it "latest_score が返ること" do
        expect(described_class.call(customer).latest_score).to eq 75
      end

      it "recent_growth_label が nil であること（前回なし）" do
        expect(described_class.call(customer).recent_growth_label).to be_nil
      end

      it "recent_growth_delta_label が nil であること" do
        expect(described_class.call(customer).recent_growth_delta_label).to be_nil
      end
    end

    context "完了済み診断が複数ある場合" do
      before do
        completed_with_score(overall: 65, created_at: 3.days.ago)
        completed_with_score(overall: 80, created_at: 1.day.ago)
      end

      it "diagnosis_count が正しく返ること" do
        expect(described_class.call(customer).diagnosis_count).to eq 2
      end

      it "best_score が最高値を返すこと" do
        expect(described_class.call(customer).best_score).to eq 80
      end

      it "latest_score が最新の診断のスコアを返すこと" do
        expect(described_class.call(customer).latest_score).to eq 80
      end
    end

    context "streak_days が返ること" do
      before { completed_with_score(overall: 70, created_at: Time.zone.today.beginning_of_day) }

      it "0 以上の整数が返ること" do
        expect(described_class.call(customer).streak_days).to be_a(Integer)
        expect(described_class.call(customer).streak_days).to be >= 0
      end
    end

    context "recent_growth の計算" do
      context "直近 2 件で expression_score が最も伸びた場合" do
        before do
          completed_with_score(overall: 70, pitch: 68, rhythm: 70, expression: 60, created_at: 2.days.ago)
          completed_with_score(overall: 75, pitch: 70, rhythm: 72, expression: 80, created_at: 1.day.ago)
        end

        it "最大デルタのスコア名を返すこと" do
          result = described_class.call(customer)
          expect(result.recent_growth_label).to eq "表現力"
        end

        it "デルタ文字列を +XX 形式で返すこと" do
          result = described_class.call(customer)
          expect(result.recent_growth_delta_label).to eq "+20"
        end
      end

      context "前回より全スコアが下がった場合" do
        before do
          completed_with_score(overall: 80, pitch: 80, rhythm: 80, expression: 80, created_at: 2.days.ago)
          completed_with_score(overall: 70, pitch: 70, rhythm: 70, expression: 70, created_at: 1.day.ago)
        end

        it "recent_growth_label が nil を返すこと" do
          expect(described_class.call(customer).recent_growth_label).to be_nil
        end
      end

      context "前回がない（1 件だけ）の場合" do
        before { completed_with_score(overall: 80) }

        it "recent_growth_label が nil を返すこと" do
          expect(described_class.call(customer).recent_growth_label).to be_nil
        end
      end
    end

    context "他のユーザーの診断を参照しないこと" do
      let(:other) { create(:customer, domain_name: "singing") }
      before { completed_with_score(overall: 99) }

      it "対象 customer のみカウントすること" do
        create(:singing_diagnosis, :completed, customer: other, overall_score: 50)
        expect(described_class.call(customer).diagnosis_count).to eq 1
      end
    end
  end
end
