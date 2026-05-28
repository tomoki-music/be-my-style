require "rails_helper"

RSpec.describe Singing::MissionProgressAnalyzer, type: :service do
  let(:customer) { FactoryBot.create(:customer, domain_name: "singing") }

  def build_diagnosis(attrs = {})
    FactoryBot.create(
      :singing_diagnosis,
      :completed,
      customer: customer,
      **attrs
    )
  end

  describe ".call" do
    context "前回診断にミッションがない" do
      let(:previous) { build_diagnosis }
      let(:current)  { build_diagnosis }

      it "nil を返す" do
        expect(described_class.call(current, previous)).to be_nil
      end
    end

    context "前回ミッションがリズム関連で、今回リズムスコアが伸びた" do
      let(:previous) do
        build_diagnosis(
          rhythm_score: 60,
          next_mission_title: "リズム安定チャレンジ",
          next_mission_body:  "次回はリズムに合わせて身体を揺らしながら歌ってみましょう"
        )
      end

      let(:current) { build_diagnosis(rhythm_score: 70) }

      it "success? が true" do
        result = described_class.call(current, previous)
        expect(result).not_to be_nil
        expect(result.success?).to be true
      end

      it "score_label が「リズム」" do
        result = described_class.call(current, previous)
        expect(result.score_label).to eq "リズム"
      end

      it "delta が 10" do
        result = described_class.call(current, previous)
        expect(result.delta).to eq 10
      end
    end

    context "前回ミッションがリズム関連だが、今回スコアが改善幅不足" do
      let(:previous) do
        build_diagnosis(
          rhythm_score: 70,
          next_mission_title: "リズム改善",
          next_mission_body:  "リズムを意識してみましょう"
        )
      end

      let(:current) { build_diagnosis(rhythm_score: 72) }

      it "success? が false（閾値 3 未満）" do
        result = described_class.call(current, previous)
        expect(result).not_to be_nil
        expect(result.success?).to be false
      end
    end

    context "ミッションキーワードが一致しないが、最大成長スコアがある" do
      let(:previous) do
        build_diagnosis(
          overall_score: 60,
          pitch_score: 60,
          next_mission_title: "頑張る",
          next_mission_body:  "引き続き練習しましょう"
        )
      end

      let(:current) { build_diagnosis(overall_score: 70, pitch_score: 68) }

      it "nil または Result を返す（クラッシュしない）" do
        result = described_class.call(current, previous)
        expect { result }.not_to raise_error
      end
    end

    context "引数が nil" do
      it "current が nil でも nil を返す" do
        expect(described_class.call(nil, build_diagnosis)).to be_nil
      end

      it "previous が nil でも nil を返す" do
        expect(described_class.call(build_diagnosis, nil)).to be_nil
      end
    end
  end
end
