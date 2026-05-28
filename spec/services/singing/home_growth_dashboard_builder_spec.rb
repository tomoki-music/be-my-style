require "rails_helper"

RSpec.describe Singing::HomeGrowthDashboardBuilder do
  let(:customer) { create(:customer, domain_name: "singing") }

  def completed_diagnosis(overall: 75, mission_title: nil, mission_body: nil, created_at: Time.current)
    create(:singing_diagnosis, :completed,
           customer: customer,
           overall_score: overall,
           next_mission_title: mission_title,
           next_mission_body: mission_body,
           created_at: created_at,
           diagnosed_at: created_at)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_diagnoses: false を返すこと" do
        result = described_class.call(nil)
        expect(result.has_diagnoses).to be false
      end

      it "latest_diagnosis が nil であること" do
        expect(described_class.call(nil).latest_diagnosis).to be_nil
      end

      it "next_mission_title が nil であること" do
        expect(described_class.call(nil).next_mission_title).to be_nil
      end
    end

    context "完了済み診断が 0 件の場合" do
      before { create(:singing_diagnosis, customer: customer, status: :queued) }

      it "has_diagnoses: false を返すこと" do
        expect(described_class.call(customer).has_diagnoses).to be false
      end

      it "latest_diagnosis が nil であること" do
        expect(described_class.call(customer).latest_diagnosis).to be_nil
      end
    end

    context "完了済み診断が 1 件ある場合" do
      let!(:diagnosis) { completed_diagnosis(overall: 80) }

      it "has_diagnoses: true を返すこと" do
        expect(described_class.call(customer).has_diagnoses).to be true
      end

      it "summary が JourneySummaryBuilder の Result であること" do
        result = described_class.call(customer)
        expect(result.summary).to be_a(Singing::JourneySummaryBuilder::Result)
        expect(result.summary.diagnosis_count).to eq 1
        expect(result.summary.best_score).to eq 80
      end

      it "latest_diagnosis が最新の診断を返すこと" do
        expect(described_class.call(customer).latest_diagnosis).to eq diagnosis
      end
    end

    context "ミッションがある場合" do
      before do
        completed_diagnosis(
          mission_title: "Aメロのリズム安定",
          mission_body:  "小さく身体を揺らしながら歌う"
        )
      end

      it "next_mission_title を返すこと" do
        expect(described_class.call(customer).next_mission_title).to eq "Aメロのリズム安定"
      end

      it "next_mission_body を返すこと" do
        expect(described_class.call(customer).next_mission_body).to eq "小さく身体を揺らしながら歌う"
      end
    end

    context "ミッションがない場合" do
      before { completed_diagnosis(mission_title: nil, mission_body: nil) }

      it "next_mission_title が nil であること" do
        expect(described_class.call(customer).next_mission_title).to be_nil
      end

      it "next_mission_body が nil であること" do
        expect(described_class.call(customer).next_mission_body).to be_nil
      end
    end

    context "診断が複数ある場合" do
      let!(:old_diagnosis) { completed_diagnosis(overall: 65, created_at: 3.days.ago) }
      let!(:latest)        { completed_diagnosis(overall: 82, created_at: 1.hour.ago) }

      it "latest_diagnosis が最新の診断を返すこと" do
        expect(described_class.call(customer).latest_diagnosis).to eq latest
      end

      it "summary の diagnosis_count が全件数を返すこと" do
        expect(described_class.call(customer).summary.diagnosis_count).to eq 2
      end
    end
  end
end
