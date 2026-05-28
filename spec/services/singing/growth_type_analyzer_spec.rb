require "rails_helper"

RSpec.describe Singing::GrowthTypeAnalyzer do
  let(:customer) { create(:customer, domain_name: "singing") }

  def completed_diagnosis(overall: 75, pitch: 72, rhythm: 76, expression: 73, created_at: Time.current)
    create(:singing_diagnosis, :completed,
           customer:          customer,
           overall_score:     overall,
           pitch_score:       pitch,
           rhythm_score:      rhythm,
           expression_score:  expression,
           created_at:        created_at,
           diagnosed_at:      created_at)
  end

  describe ".call" do
    context "診断0件の場合" do
      it "groove_builder を返すこと" do
        result = described_class.call(customer)
        expect(result.type_key).to eq(:groove_builder)
      end

      it "label / icon / description が存在すること" do
        result = described_class.call(customer)
        expect(result.label).to be_present
        expect(result.icon).to be_present
        expect(result.description).to be_present
      end
    end

    context "診断1件でも落ちないこと" do
      before { completed_diagnosis }

      it "Result を返すこと" do
        expect { described_class.call(customer) }.not_to raise_error
      end

      it "Result が type_key を持つこと" do
        result = described_class.call(customer)
        expect(result.type_key).to be_present
      end
    end

    context "streak 7日以上で consistency_hero" do
      before do
        7.times { |i| completed_diagnosis(created_at: i.days.ago) }
      end

      it "consistency_hero を返すこと" do
        result = described_class.call(customer)
        expect(result.type_key).to eq(:consistency_hero)
      end
    end

    context "overall >= 70 かつ 3スコア差 <= 10 で dynamic_performer" do
      before do
        # 2件以上でも直近だけ見る
        completed_diagnosis(overall: 72, pitch: 70, rhythm: 74, expression: 72, created_at: 2.days.ago)
        completed_diagnosis(overall: 78, pitch: 75, rhythm: 78, expression: 72, created_at: 1.day.ago)
      end

      it "dynamic_performer を返すこと" do
        result = described_class.call(customer)
        expect(result.type_key).to eq(:dynamic_performer)
      end
    end

    context "rhythm 平均最高で rhythm_explorer" do
      before do
        # overall < 70 で dynamic_performer を除外、rhythm が圧倒的に高い
        completed_diagnosis(overall: 60, pitch: 58, rhythm: 88, expression: 62, created_at: 2.days.ago)
        completed_diagnosis(overall: 62, pitch: 60, rhythm: 90, expression: 63, created_at: 1.day.ago)
      end

      it "rhythm_explorer を返すこと" do
        result = described_class.call(customer)
        expect(result.type_key).to eq(:rhythm_explorer)
      end
    end

    context "expression 成長が突出して emotional_singer" do
      before do
        # overall < 70 で dynamic_performer を除外、expression だけ大きく伸びる
        completed_diagnosis(overall: 60, pitch: 70, rhythm: 68, expression: 58, created_at: 2.days.ago)
        completed_diagnosis(overall: 64, pitch: 72, rhythm: 69, expression: 78, created_at: 1.day.ago)
      end

      it "emotional_singer を返すこと" do
        result = described_class.call(customer)
        expect(result.type_key).to eq(:emotional_singer)
      end
    end

    context "pitch 成長で voice_challenger" do
      before do
        # overall < 70 で dynamic_performer 除外、rhythm 平均は pitch より低い、expression 成長は pitch より小
        completed_diagnosis(overall: 60, pitch: 58, rhythm: 60, expression: 64, created_at: 2.days.ago)
        completed_diagnosis(overall: 65, pitch: 80, rhythm: 62, expression: 66, created_at: 1.day.ago)
      end

      it "voice_challenger を返すこと" do
        result = described_class.call(customer)
        expect(result.type_key).to eq(:voice_challenger)
      end
    end

    context "nil score が混在する場合" do
      before do
        # pitch / rhythm / expression が nil でも落ちないこと
        create(:singing_diagnosis, :completed,
               customer:         customer,
               overall_score:    70,
               pitch_score:      nil,
               rhythm_score:     nil,
               expression_score: nil,
               diagnosed_at:     2.days.ago,
               created_at:       2.days.ago)
        completed_diagnosis(overall: 75, created_at: 1.day.ago)
      end

      it "落ちないこと" do
        expect { described_class.call(customer) }.not_to raise_error
      end

      it "有効な type_key を返すこと" do
        result = described_class.call(customer)
        expect(Singing::GrowthTypeAnalyzer::GROWTH_TYPES.keys).to include(result.type_key)
      end
    end

    context "customer が nil の場合" do
      it "groove_builder を返すこと" do
        result = described_class.call(nil)
        expect(result.type_key).to eq(:groove_builder)
      end

      it "落ちないこと" do
        expect { described_class.call(nil) }.not_to raise_error
      end
    end
  end
end
