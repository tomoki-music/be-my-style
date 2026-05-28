require "rails_helper"

RSpec.describe Singing::JourneyRecapBuilder do
  let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :passionate) }

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
      it "has_story: false を返すこと" do
        expect(described_class.call(nil).has_story).to be false
      end

      it "diagnosis_count が 0 であること" do
        expect(described_class.call(nil).diagnosis_count).to eq 0
      end

      it "streak_days が 0 であること" do
        expect(described_class.call(nil).streak_days).to eq 0
      end

      it "各フィールドが nil 安全であること" do
        result = described_class.call(nil)
        expect(result.growth_story).to be_nil
        expect(result.journey_story).to be_nil
        expect(result.coach_reflection).to be_nil
        expect(result.most_improved_label).to be_nil
        expect(result.most_improved_delta).to be_nil
      end
    end

    context "診断なしの場合" do
      it "has_story: false を返すこと" do
        expect(described_class.call(customer).has_story).to be false
      end
    end

    context "診断 1 件の場合（early story）" do
      before { completed_with_scores(overall: 70) }

      it "has_story: true を返すこと" do
        expect(described_class.call(customer).has_story).to be true
      end

      it "diagnosis_count が 1 であること" do
        expect(described_class.call(customer).diagnosis_count).to eq 1
      end

      it "各ストーリーフィールドが存在すること" do
        result = described_class.call(customer)
        expect(result.growth_story).to be_present
        expect(result.journey_story).to be_present
        expect(result.coach_reflection).to be_present
      end
    end

    context "診断 2 件以上の場合" do
      before do
        completed_with_scores(overall: 60, pitch: 55, rhythm: 58, expression: 50, created_at: 5.weeks.ago)
        completed_with_scores(overall: 78, pitch: 72, rhythm: 74, expression: 80, created_at: 1.day.ago)
      end

      it "has_story: true を返すこと" do
        expect(described_class.call(customer).has_story).to be true
      end

      it "diagnosis_count が 2 であること" do
        expect(described_class.call(customer).diagnosis_count).to eq 2
      end

      it "most_improved_label が存在すること" do
        result = described_class.call(customer)
        expect(result.most_improved_label).to be_present
      end

      it "most_improved_delta が正の整数であること" do
        result = described_class.call(customer)
        expect(result.most_improved_delta).to be_a(Integer)
        expect(result.most_improved_delta).to be > 0
      end

      it "growth_story にラベルとデルタが反映されること" do
        result = described_class.call(customer)
        expect(result.growth_story).to include(result.most_improved_label)
        expect(result.growth_story).to include(result.most_improved_delta.to_s)
      end
    end

    context "coach_personality が反映されること" do
      before do
        completed_with_scores(overall: 60, created_at: 3.weeks.ago)
        completed_with_scores(overall: 75, created_at: 1.day.ago)
      end

      it "gentle の場合に growth_story が存在すること" do
        customer.update!(singing_coach_personality: :gentle)
        result = described_class.call(customer)
        expect(result.growth_story).to be_present
      end

      it "artist の場合に growth_story が存在すること" do
        customer.update!(singing_coach_personality: :artist)
        result = described_class.call(customer)
        expect(result.growth_story).to be_present
      end

      it "personality が異なれば coach_reflection も異なること" do
        customer.update!(singing_coach_personality: :passionate)
        passionate_result = described_class.call(customer)

        customer.update!(singing_coach_personality: :artist)
        artist_result = described_class.call(customer)

        expect(passionate_result.coach_reflection).not_to eq artist_result.coach_reflection
      end
    end

    context "streak_days が返ること" do
      before { completed_with_scores(overall: 72) }

      it "0 以上の整数であること" do
        result = described_class.call(customer)
        expect(result.streak_days).to be_a(Integer)
        expect(result.streak_days).to be >= 0
      end
    end

    context "他のユーザーの診断を参照しないこと" do
      let(:other) { create(:customer, domain_name: "singing") }

      before do
        completed_with_scores(overall: 70)
        create(:singing_diagnosis, :completed, customer: other, overall_score: 90)
      end

      it "対象 customer の diagnosis_count のみ返すこと" do
        expect(described_class.call(customer).diagnosis_count).to eq 1
      end
    end
  end
end
