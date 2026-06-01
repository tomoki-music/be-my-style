require "rails_helper"

RSpec.describe Singing::CoachReflectionBuilder do
  let(:customer) { create(:customer, domain_name: "singing", singing_coach_personality: :passionate) }

  def build_memory(diagnosis_count: 3, max_streak: 0, strongest_label: "音程", strongest_delta: 5,
                   recent_trend: nil, weeks: 4, has_memory: true)
    Singing::CoachMemoryBuilder::CoachMemory.new(
      first_diagnosis_at:     4.weeks.ago.to_date,
      growth_type:            nil,
      strongest_growth_label: strongest_label,
      strongest_growth_delta: strongest_delta,
      max_streak:             max_streak,
      recent_trend_label:     recent_trend,
      diagnosis_count:        diagnosis_count,
      weeks_since_start:      weeks,
      has_memory:             has_memory
    )
  end

  def build_diagnosis(pitch: 70, rhythm: 60, expression: 65, overall: 68)
    create(:singing_diagnosis, :completed,
           customer:         customer,
           overall_score:    overall,
           pitch_score:      pitch,
           rhythm_score:     rhythm,
           expression_score: expression)
  end

  describe ".call" do
    context "customer が nil の場合" do
      it "has_reflection: false を返す" do
        memory    = build_memory
        diagnosis = build_diagnosis
        result    = described_class.call(nil, diagnosis, memory)
        expect(result.has_reflection).to be false
      end
    end

    context "memory が nil の場合" do
      it "has_reflection: false を返す" do
        diagnosis = build_diagnosis
        result    = described_class.call(customer, diagnosis, nil)
        expect(result.has_reflection).to be false
      end
    end

    context "has_memory が false の場合" do
      it "has_reflection: false を返す" do
        memory    = build_memory(has_memory: false)
        diagnosis = build_diagnosis
        result    = described_class.call(customer, diagnosis, memory)
        expect(result.has_reflection).to be false
      end
    end

    context "正常な入力の場合" do
      let(:memory)    { build_memory }
      let(:diagnosis) { build_diagnosis }
      subject(:result) { described_class.call(customer, diagnosis, memory) }

      it "has_reflection: true を返す" do
        expect(result.has_reflection).to be true
      end

      it "remember が文字列を返す" do
        expect(result.remember).to be_a(String).and be_present
      end

      it "recognize が文字列を返す" do
        expect(result.recognize).to be_a(String).and be_present
      end

      it "next_step が文字列を返す" do
        expect(result.next_step).to be_a(String).and be_present
      end

      it "full_message が3つのセクションを含む" do
        expect(result.full_message).to be_a(String).and be_present
      end

      it "coach_icon が返ること" do
        expect(result.coach_icon).to be_present
      end

      it "coach_label が返ること" do
        expect(result.coach_label).to be_present
      end
    end

    context "3日連続ストリークがある場合" do
      it "recognize がストリーク系メッセージを返す" do
        memory    = build_memory(max_streak: 5, recent_trend: nil)
        diagnosis = build_diagnosis
        result    = described_class.call(customer, diagnosis, memory)
        expect(result.recognize).to match(/5/)
      end
    end

    context "初回診断（1件）の場合" do
      it "remember が early 系メッセージを返す" do
        memory    = build_memory(diagnosis_count: 1, strongest_delta: 0, weeks: 0)
        diagnosis = build_diagnosis
        result    = described_class.call(customer, diagnosis, memory)
        expect(result.remember).to be_present
      end
    end

    context "コーチパーソナリティ: gentle の場合" do
      let(:gentle_customer) { create(:customer, domain_name: "singing", singing_coach_personality: :gentle) }

      it "coach_label が優しい先生 を返す" do
        memory    = build_memory
        diagnosis = build_diagnosis
        result    = described_class.call(gentle_customer, diagnosis, memory)
        expect(result.coach_label).to eq "優しい先生"
      end
    end

    context "コーチパーソナリティ: artist の場合" do
      let(:artist_customer) { create(:customer, domain_name: "singing", singing_coach_personality: :artist) }

      it "coach_icon が 🎨 を返す" do
        memory    = build_memory
        diagnosis = build_diagnosis
        result    = described_class.call(artist_customer, diagnosis, memory)
        expect(result.coach_icon).to eq "🎨"
      end
    end
  end
end
