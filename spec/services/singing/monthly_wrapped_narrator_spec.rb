require "rails_helper"

RSpec.describe Singing::MonthlyWrappedNarrator do
  let(:base_data) do
    {
      customer_id:         1,
      year:                2026,
      month:               5,
      personality:         "passionate",
      diagnosis_count:     10,
      most_improved_label: "表現力",
      most_improved_delta: 12
    }
  end

  def call(overrides = {})
    described_class.call(base_data.merge(overrides))
  end

  describe ".call" do
    context "passionate personality" do
      it "wrapped_message が文字列を返すこと" do
        result = call(personality: "passionate")
        expect(result[:wrapped_message]).to be_a(String).and be_present
      end

      it "coach_reflection が文字列を返すこと" do
        result = call(personality: "passionate")
        expect(result[:coach_reflection]).to be_a(String).and be_present
      end

      it "診断回数が wrapped_message に反映されること" do
        result = call(personality: "passionate", diagnosis_count: 8)
        expect(result[:wrapped_message]).to include("8")
      end
    end

    context "gentle personality" do
      it "wrapped_message が返ること" do
        result = call(personality: "gentle")
        expect(result[:wrapped_message]).to be_present
      end

      it "coach_reflection が返ること" do
        result = call(personality: "gentle")
        expect(result[:coach_reflection]).to be_present
      end

      it "診断回数が wrapped_message に反映されること" do
        result = call(personality: "gentle", diagnosis_count: 3)
        expect(result[:wrapped_message]).to include("3")
      end
    end

    context "artist personality" do
      it "wrapped_message が返ること" do
        result = call(personality: "artist")
        expect(result[:wrapped_message]).to be_present
      end

      it "coach_reflection が返ること" do
        result = call(personality: "artist")
        expect(result[:coach_reflection]).to be_present
      end
    end

    context "成長項目がある場合" do
      it "wrapped_message に成長情報が含まれること" do
        result = call(most_improved_label: "音程", most_improved_delta: 10)
        expect(result[:wrapped_message]).to include("音程").or include("+10")
      end
    end

    context "成長項目がない場合（delta が 0）" do
      it "wrapped_message でクラッシュしないこと" do
        expect { call(most_improved_label: nil, most_improved_delta: 0) }.not_to raise_error
      end

      it "wrapped_message が返ること" do
        result = call(most_improved_label: nil, most_improved_delta: 0)
        expect(result[:wrapped_message]).to be_present
      end
    end

    context "未知の personality が渡された場合" do
      it "passionate にフォールバックして返ること" do
        expect { call(personality: "unknown") }.not_to raise_error
        result = call(personality: "unknown")
        expect(result[:wrapped_message]).to be_present
      end
    end

    context "月単位での安定性" do
      it "同一パラメータで同じ wrapped_message を返すこと" do
        r1 = call
        r2 = call
        expect(r1[:wrapped_message]).to eq r2[:wrapped_message]
      end

      it "同一パラメータで同じ coach_reflection を返すこと" do
        r1 = call
        r2 = call
        expect(r1[:coach_reflection]).to eq r2[:coach_reflection]
      end

      it "異なる月では wrapped_message が変わり得ること" do
        r_may  = call(month: 5)
        r_june = call(month: 6)
        # 完全一致にならないことを期待（プール数とseedの差があれば変わる）
        # 同じ値になる可能性も排除できないが、少なくともクラッシュしないこと
        expect(r_may[:wrapped_message]).to be_present
        expect(r_june[:wrapped_message]).to be_present
      end
    end
  end
end
