require "rails_helper"

RSpec.describe SingingDiagnoses::VoiceTypeAnalyzer do
  # result_payload を持つ軽量なスタブを使う（DB 不要）
  def build_diagnosis(overall:, pitch:, rhythm:, expression:, specific: {})
    instance_double(
      SingingDiagnosis,
      overall_score:    overall,
      pitch_score:      pitch,
      rhythm_score:     rhythm,
      expression_score: expression,
      id:               1,
      result_payload:   specific.empty? ? nil : { "specific" => specific }
    )
  end

  describe ".call" do
    subject(:result) { described_class.call(diagnosis) }

    context "高音が突出したプロファイル (ハイトーンボイス)" do
      let(:diagnosis) do
        build_diagnosis(
          overall: 80, pitch: 92, rhythm: 75, expression: 68,
          specific: { "relax_score" => 80, "volume_score" => 62, "mix_voice_score" => 88 }
        )
      end

      it "main_type が high_tone になること" do
        expect(result[:main_type]).to eq(:high_tone)
      end

      it "wild スコアが低いこと (エッジ・緊張要素がないため)" do
        expect(result[:scores][:wild]).to be < 60
      end

      it "6タイプすべてのスコアが含まれること" do
        expect(result[:scores].keys).to match_array(%i[powerful high_tone crystal wild artistic charisma])
      end
    end

    context "透明感・リラックスが高いプロファイル (クリスタルボイス)" do
      let(:diagnosis) do
        build_diagnosis(
          overall: 74, pitch: 82, rhythm: 70, expression: 63,
          specific: { "relax_score" => 90, "volume_score" => 52, "mix_voice_score" => 76 }
        )
      end

      it "main_type が crystal になること" do
        expect(result[:main_type]).to eq(:crystal)
      end

      it "wild スコアが low であること (リラックス高 = 緊張低)" do
        expect(result[:scores][:wild]).to be < 55
      end
    end

    context "声量+表現が高いパワフルプロファイル (パワフルボイス)" do
      let(:diagnosis) do
        build_diagnosis(
          overall: 85, pitch: 74, rhythm: 80, expression: 84,
          specific: { "relax_score" => 55, "volume_score" => 92, "mix_voice_score" => 68 }
        )
      end

      it "main_type が powerful になること" do
        expect(result[:main_type]).to eq(:powerful)
      end
    end

    context "表現と声帯緊張度が両方高いプロファイル (ワイルドボイス)" do
      let(:diagnosis) do
        build_diagnosis(
          overall: 68, pitch: 60, rhythm: 70, expression: 90,
          specific: { "relax_score" => 22, "volume_score" => 82, "mix_voice_score" => 58 }
        )
      end

      it "main_type が wild になること" do
        expect(result[:main_type]).to eq(:wild)
      end

      it "crystal スコアが低いこと (リラックスが低いため透明感がない)" do
        expect(result[:scores][:crystal]).to be < 55
      end
    end

    context "緊張度なしで expression だけ高いプロファイルは wild にならない" do
      let(:diagnosis) do
        build_diagnosis(
          overall: 80, pitch: 78, rhythm: 82, expression: 88,
          specific: { "relax_score" => 85, "volume_score" => 74, "mix_voice_score" => 76 }
        )
      end

      it "wild が main_type でないこと" do
        expect(result[:main_type]).not_to eq(:wild)
      end

      it "wild スコアが他の上位タイプより低いこと" do
        wild_score = result[:scores][:wild]
        top_score  = result[:scores].max_by { |_, s| s }[1]
        expect(wild_score).to be < top_score
      end
    end

    context "リズム+表現が突出したプロファイル (アーティスティックボイス)" do
      let(:diagnosis) do
        build_diagnosis(
          overall: 72, pitch: 70, rhythm: 90, expression: 84,
          specific: {
            "relax_score" => 65, "volume_score" => 65,
            "mix_voice_score" => 68, "pronunciation_score" => 86
          }
        )
      end

      it "main_type が artistic になること" do
        expect(result[:main_type]).to eq(:artistic)
      end
    end

    context "全スコアがバランスよく高いプロファイル (カリスマ)" do
      let(:diagnosis) do
        build_diagnosis(
          overall: 86, pitch: 84, rhythm: 85, expression: 90,
          specific: { "relax_score" => 62, "volume_score" => 76, "mix_voice_score" => 80 }
        )
      end

      it "main_type が charisma になること" do
        expect(result[:main_type]).to eq(:charisma)
      end
    end

    context "スコア構造の共通検証" do
      let(:diagnosis) do
        build_diagnosis(overall: 75, pitch: 72, rhythm: 76, expression: 73)
      end

      it "main_type と sub_type が異なること" do
        expect(result[:main_type]).not_to eq(result[:sub_type])
      end

      it "すべてのスコアが 0〜100 の範囲に収まること" do
        result[:scores].each_value do |score|
          expect(score).to be_between(0, 100)
        end
      end

      it "labels・descriptions・advice・song_tendency を含むこと" do
        %i[labels descriptions advice song_tendency].each do |key|
          expect(result[key]).to be_a(Hash)
          expect(result[key].keys).to match_array(%i[powerful high_tone crystal wild artistic charisma])
        end
      end

      it "reasoning が文字列であること" do
        expect(result[:reasoning]).to be_a(String)
        expect(result[:reasoning]).not_to be_empty
      end
    end

    context "result_payload がない場合 (specific スコアなし)" do
      let(:diagnosis) do
        build_diagnosis(overall: 75, pitch: 72, rhythm: 76, expression: 73)
      end

      it "エラーなく 6タイプのスコアを返すこと" do
        expect { result }.not_to raise_error
        expect(result[:scores].keys.size).to eq(6)
      end
    end

    context "hidden_potential の検証" do
      let(:diagnosis) do
        build_diagnosis(
          overall: 80, pitch: 88, rhythm: 75, expression: 68,
          specific: { "relax_score" => 78, "volume_score" => 60, "mix_voice_score" => 86 }
        )
      end

      it "hidden_potential が nil または 6タイプのいずれかのキーであること" do
        hp = result[:hidden_potential]
        valid_keys = %i[powerful high_tone crystal wild artistic charisma] + [nil]
        expect(valid_keys).to include(hp)
      end

      it "hidden_potential が main_type・sub_type と異なること (nil 以外の場合)" do
        hp = result[:hidden_potential]
        next if hp.nil?

        expect(hp).not_to eq(result[:main_type])
        expect(hp).not_to eq(result[:sub_type])
      end
    end
  end
end
