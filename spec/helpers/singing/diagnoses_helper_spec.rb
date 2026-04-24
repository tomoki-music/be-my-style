require 'rails_helper'

RSpec.describe Singing::DiagnosesHelper, type: :helper do
  describe "#singing_score_guide" do
    it "スコア説明文を返すこと" do
      guide = helper.singing_score_guide(:pitch)

      expect(guide[:label]).to eq "音程"
      expect(guide[:description]).to include "目安"
    end
  end

  describe "#singing_score_comment" do
    it "高めのスコアに前向きなコメントを返すこと" do
      expect(helper.singing_score_comment(85)).to include "安定感"
    end

    it "中間のスコアに伸ばしどころを示すコメントを返すこと" do
      expect(helper.singing_score_comment(70)).to include "土台"
    end

    it "低めのスコアに改善支援のコメントを返すこと" do
      expect(helper.singing_score_comment(45)).to include "伸ばしどころ"
    end
  end

  describe "#singing_practice_menus" do
    it "音程が低めの場合は音程系メニューを含むこと" do
      diagnosis = build_diagnosis(pitch_score: 55, rhythm_score: 82, expression_score: 84)

      menus = helper.singing_practice_menus(diagnosis)

      expect(menus.map { |menu| menu[:title] }).to include "ロングトーン安定練習"
    end

    it "リズムが低めの場合はリズム系メニューを含むこと" do
      diagnosis = build_diagnosis(pitch_score: 82, rhythm_score: 55, expression_score: 84)

      menus = helper.singing_practice_menus(diagnosis)

      expect(menus.map { |menu| menu[:title] }).to include "メトロノーム入り練習"
    end

    it "表現が低めの場合は表現系メニューを含むこと" do
      diagnosis = build_diagnosis(pitch_score: 82, rhythm_score: 84, expression_score: 55)

      menus = helper.singing_practice_menus(diagnosis)

      expect(menus.map { |menu| menu[:title] }).to include "サビ前後の強弱練習"
    end

    it "提案は最大3件に絞ること" do
      diagnosis = build_diagnosis(pitch_score: 50, rhythm_score: 50, expression_score: 50)

      expect(helper.singing_practice_menus(diagnosis).size).to be <= 3
    end

    it "guitarではギター向けメニューを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "guitar",
        rhythm_score: 65,
        result_payload: {
          "specific" => {
            "attack_score" => 62,
            "muting_score" => 68,
            "stability_score" => 72
          }
        }
      )

      menus = helper.singing_practice_menus(diagnosis)

      expect(menus.map { |menu| menu[:title] }).to include "ピッキングの立ち上がり確認"
      expect(menus.map { |menu| menu[:title] }).not_to include "ロングトーン安定練習"
    end
  end

  describe "#singing_advanced_feedback_cards" do
    it "高めの音程スコアに安定感のフィードバックを返すこと" do
      diagnosis = build_diagnosis(pitch_score: 85, rhythm_score: 70, expression_score: 70)

      card = helper.singing_advanced_feedback_cards(diagnosis).find { |feedback| feedback[:label] == "音程" }

      expect(card[:band]).to eq :high
      expect(card[:summary]).to include "声の位置を保ちやすい"
    end

    it "中間のリズムスコアに細かなタイミングのフィードバックを返すこと" do
      diagnosis = build_diagnosis(pitch_score: 85, rhythm_score: 70, expression_score: 70)

      card = helper.singing_advanced_feedback_cards(diagnosis).find { |feedback| feedback[:label] == "リズム" }

      expect(card[:band]).to eq :middle
      expect(card[:next_step]).to include "歌い始め"
    end

    it "低めの表現スコアに改善支援のフィードバックを返すこと" do
      diagnosis = build_diagnosis(pitch_score: 85, rhythm_score: 70, expression_score: 45)

      card = helper.singing_advanced_feedback_cards(diagnosis).find { |feedback| feedback[:label] == "表現" }

      expect(card[:band]).to eq :low
      expect(card[:strength]).to include "小さな変化"
    end

    it "guitarではアタック・ミュート・安定感・全体のまとまりを返すこと" do
      diagnosis = build_diagnosis(
        overall_score: 76,
        performance_type: "guitar",
        result_payload: {
          "specific" => {
            "attack_score" => 84,
            "muting_score" => 68,
            "stability_score" => 45
          }
        }
      )

      cards = helper.singing_advanced_feedback_cards(diagnosis)

      expect(cards.map { |card| card[:label] }).to eq ["アタック", "ミュート", "安定感", "全体のまとまり"]
      expect(cards.find { |card| card[:label] == "アタック" }[:summary]).to include "音の立ち上がりがはっきり"
      expect(cards.find { |card| card[:label] == "ミュート" }[:band]).to eq :middle
      expect(cards.find { |card| card[:label] == "安定感" }[:next_step]).to include "ゆっくりのテンポ"
    end

    it "bassではグルーヴ・音価・安定感・全体のまとまりを返すこと" do
      diagnosis = build_diagnosis(
        overall_score: 76,
        performance_type: "bass",
        result_payload: {
          "specific" => {
            "groove_score" => 84,
            "note_length_score" => 68,
            "stability_score" => 45
          }
        }
      )

      cards = helper.singing_advanced_feedback_cards(diagnosis)

      expect(cards.map { |card| card[:label] }).to eq ["グルーヴ", "音価", "安定感", "全体のまとまり"]
      expect(cards.find { |card| card[:label] == "グルーヴ" }[:summary]).to include "気持ちよく前へ進む流れ"
      expect(cards.find { |card| card[:label] == "音価" }[:band]).to eq :middle
      expect(cards.find { |card| card[:label] == "安定感" }[:next_step]).to include "ゆっくりのテンポ"
    end

    it "drumsではテンポ安定・リズム精度・ダイナミクス・フィルコントロール・全体のまとまりを返すこと" do
      diagnosis = build_diagnosis(
        overall_score: 76,
        performance_type: "drums",
        result_payload: {
          "specific" => {
            "tempo_stability_score" => 84,
            "rhythm_precision_score" => 68,
            "dynamics_score" => 45,
            "fill_control_score" => 73
          }
        }
      )

      cards = helper.singing_advanced_feedback_cards(diagnosis)

      expect(cards.map { |card| card[:label] }).to eq ["テンポ安定", "リズム精度", "ダイナミクス", "フィルコントロール", "全体のまとまり"]
      expect(cards.find { |card| card[:label] == "テンポ安定" }[:summary]).to include "ビートの土台が安定"
      expect(cards.find { |card| card[:label] == "リズム精度" }[:band]).to eq :middle
      expect(cards.find { |card| card[:label] == "ダイナミクス" }[:next_step]).to include "強弱の役割"
      expect(cards.find { |card| card[:label] == "フィルコントロール" }[:summary]).to include "フィルの流れ"
    end

    it "keyboardではコード安定・音のつながり・タッチ・ハーモニー・全体のまとまりを返すこと" do
      diagnosis = build_diagnosis(
        overall_score: 76,
        performance_type: "keyboard",
        result_payload: {
          "specific" => {
            "chord_stability_score" => 84,
            "note_connection_score" => 68,
            "touch_score" => 45,
            "harmony_score" => 73
          }
        }
      )

      cards = helper.singing_advanced_feedback_cards(diagnosis)

      expect(cards.map { |card| card[:label] }).to eq ["コード安定", "音のつながり", "タッチ", "ハーモニー", "全体のまとまり"]
      expect(cards.find { |card| card[:label] == "コード安定" }[:summary]).to include "和音のまとまり"
      expect(cards.find { |card| card[:label] == "音のつながり" }[:band]).to eq :middle
      expect(cards.find { |card| card[:label] == "タッチ" }[:next_step]).to include "打鍵"
      expect(cards.find { |card| card[:label] == "ハーモニー" }[:summary]).to include "ハーモニー"
    end
  end

  describe "#singing_specific_scores" do
    it "result_payloadのspecificをsymbol keyで返すこと" do
      diagnosis = build_diagnosis(
        result_payload: {
          "specific" => {
            "volume_score" => 78,
            "pronunciation_score" => 72
          }
        }
      )

      expect(helper.singing_specific_scores(diagnosis)).to eq(
        volume_score: 78,
        pronunciation_score: 72
      )
    end

    it "specificがない場合は空Hashを返すこと" do
      diagnosis = build_diagnosis(result_payload: {})

      expect(helper.singing_specific_scores(diagnosis)).to eq({})
      expect(helper.singing_specific_score_cards(diagnosis)).to eq([])
    end

    it "bandではspecificがnilでも6項目のカードを安全に返すこと" do
      diagnosis = build_diagnosis(performance_type: "band", result_payload: { "specific" => nil })

      cards = helper.singing_specific_score_cards(diagnosis)

      expect(cards.size).to eq 6
      expect(cards.map { |card| card[:label] }).to eq ["音量バランス", "リズムの揃い", "グルーヴ", "役割理解", "抑揚・展開", "一体感"]
      expect(cards.map { |card| card[:score] }).to all(be_nil)
    end

    it "bandでは一部スコア欠損や文字列・範囲外でも安全に数値化すること" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "specific" => {
            "volume_balance_score" => "84",
            "rhythm_unity_score" => "105",
            "groove_score" => "-5",
            "role_understanding_score" => "abc"
          }
        }
      )

      cards = helper.singing_specific_score_cards(diagnosis)

      expect(cards.find { |card| card[:key] == :balance }[:score]).to eq 84
      expect(cards.find { |card| card[:key] == :tightness }[:score]).to eq 100
      expect(cards.find { |card| card[:key] == :groove }[:score]).to eq 0
      expect(cards.find { |card| card[:key] == :role_clarity }[:score]).to be_nil
    end

    it "vocalのspecific keyを自然なラベルに変換すること" do
      expect(helper.singing_specific_score_label(:volume_score, "vocal")).to eq "声量"
      expect(helper.singing_specific_score_label(:pronunciation_score, "vocal")).to eq "発音"
      expect(helper.singing_specific_score_label(:relax_score, "vocal")).to eq "リラックス"
      expect(helper.singing_specific_score_label(:mix_voice_score, "vocal")).to eq "ミックスボイス"
    end

    it "performance_typeごとの詳細スコアタイトルを返すこと" do
      expect(helper.singing_specific_score_section_title(build_diagnosis(performance_type: "vocal"))).to eq "ボーカル詳細スコア"
      expect(helper.singing_specific_score_section_title(build_diagnosis(performance_type: "guitar"))).to eq "ギター詳細スコア"
      expect(helper.singing_specific_score_section_title(build_diagnosis(performance_type: "bass"))).to eq "ベース詳細スコア"
      expect(helper.singing_specific_score_section_title(build_diagnosis(performance_type: "keyboard"))).to eq "キーボード詳細スコア"
      expect(helper.singing_specific_score_section_title(build_diagnosis(performance_type: "band"))).to eq "バンド演奏詳細スコア"
    end

    it "typeごとのspecific keyをラベルに変換すること" do
      expect(helper.singing_specific_score_label(:attack_score, "guitar")).to eq "アタック"
      expect(helper.singing_specific_score_label(:groove_score, "bass")).to eq "グルーヴ"
      expect(helper.singing_specific_score_label(:note_length_score, "bass")).to eq "音価"
      expect(helper.singing_specific_score_label(:stability_score, "bass")).to eq "安定感"
      expect(helper.singing_specific_score_label(:tempo_stability_score, "drums")).to eq "テンポ安定"
      expect(helper.singing_specific_score_label(:chord_stability_score, "keyboard")).to eq "コード安定"
      expect(helper.singing_specific_score_label(:note_connection_score, "keyboard")).to eq "音のつながり"
      expect(helper.singing_specific_score_label(:touch_score, "keyboard")).to eq "タッチ"
      expect(helper.singing_specific_score_label(:harmony_score, "keyboard")).to eq "ハーモニー"
      expect(helper.singing_specific_score_label(:ensemble_score, "band")).to eq "アンサンブル力"
      expect(helper.singing_specific_score_label(:role_understanding_score, "band")).to eq "役割理解"
      expect(helper.singing_specific_score_label(:volume_balance_score, "band")).to eq "音量バランス"
    end

    it "performance_typeごとの詳細スコア説明文を返すこと" do
      expect(helper.singing_specific_score_section_description(build_diagnosis(performance_type: "vocal"))).to include "ボーカル"
      expect(helper.singing_specific_score_section_description(build_diagnosis(performance_type: "guitar"))).to include "ギター演奏"
      expect(helper.singing_specific_score_section_description(build_diagnosis(performance_type: "bass"))).to include "ベース演奏"
      expect(helper.singing_specific_score_section_description(build_diagnosis(performance_type: "drums"))).to include "ドラム演奏"
      expect(helper.singing_specific_score_section_description(build_diagnosis(performance_type: "keyboard"))).to include "キーボード演奏"
      expect(helper.singing_specific_score_section_description(build_diagnosis(performance_type: "band"))).to include "バンド演奏"
    end

    it "specific比較結果を表示用の行に変換すること" do
      diagnosis = build_diagnosis(
        result_payload: { "specific" => { "volume_score" => 73 } },
        specific_comparison: {
          volume_score: {
            current: 73,
            previous: 70,
            delta: 3
          }
        }
      )

      row = helper.singing_specific_score_comparison_rows(diagnosis).first

      expect(row[:label]).to eq "声量"
      expect(row[:delta_label]).to eq "+3"
      expect(row[:state]).to eq "up"
      expect(row[:message]).to include "伸び"
    end
  end

  describe "band promo helpers" do
    it "band診断の導線用コピーを返すこと" do
      expect(helper.singing_band_promo_catch_copy).to include("アンサンブル力")
      expect(helper.singing_band_promo_description).to include("音量バランス")
      expect(helper.singing_band_promo_upload_note).to include("30秒以上")
      expect(helper.singing_band_premium_promo).to include("今週のバンド練習テーマ")
    end

    it "performance_typeカードにband用ラベルとバッジを含むこと" do
      band_card = helper.singing_performance_type_cards.find { |card| card[:key] == "band" }

      expect(band_card[:label]).to eq "バンド演奏診断"
      expect(band_card[:description]).to include("音量バランス", "一体感")
      expect(band_card[:badges]).to include("NEW", "アンサンブル対応", "Premium相性◎")
    end
  end

  describe "band analysis debug helpers" do
    it "development環境のbandでanalysis_debugがある場合だけ表示対象にすること" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "analysis_debug" => {
            "rms_mean" => 0.123456,
            "cohesion_inputs" => { "balance" => 72 }
          }
        }
      )

      expect(helper.singing_band_analysis_debug_visible?(diagnosis)).to eq true
    end

    it "production環境ではanalysis_debugを表示しないこと" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: { "analysis_debug" => { "rms_mean" => 0.123456 } }
      )

      expect(helper.singing_band_analysis_debug_visible?(diagnosis)).to eq false
    end

    it "band以外ではdevelopmentでもanalysis_debugを表示しないこと" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      diagnosis = build_diagnosis(
        performance_type: "vocal",
        result_payload: { "analysis_debug" => { "rms_mean" => 0.123456 } }
      )

      expect(helper.singing_band_analysis_debug_visible?(diagnosis)).to eq false
    end

    it "analysis_debugを画面表示向けのセクションに整形すること" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "analysis_debug" => {
            "rms_mean" => 0.123456,
            "rms_std" => "0.01234",
            "peak" => 0.98,
            "silence_ratio" => "0.135",
            "onset_count" => "14",
            "onset_interval_std" => 0.0765,
            "dynamics_range" => 0.312345,
            "spectral_balance" => {
              "low" => 0.22,
              "mid" => "0.56",
              "high" => 0.22
            },
            "cohesion_inputs" => {
              "balance" => "72",
              "tightness" => 68,
              "groove" => 70,
              "role_clarity" => "66",
              "dynamics" => 64
            }
          }
        }
      )

      sections = helper.singing_band_analysis_debug_sections(diagnosis)

      expect(sections.map { |section| section[:title] }).to eq ["基本指標", "帯域バランス", "cohesion計算入力"]
      expect(sections.first[:items]).to include(
        { label: "RMS平均", value: "0.123456" },
        { label: "RMSばらつき", value: "0.012340" },
        { label: "onset候補数", value: "14" }
      )
      expect(sections.second[:items]).to include(
        { label: "low", value: "0.220000" },
        { label: "mid", value: "0.560000" },
        { label: "high", value: "0.220000" }
      )
      expect(sections.third[:items]).to include(
        { label: "音量バランス", value: "72" },
        { label: "役割理解", value: "66" },
        { label: "ダイナミクス", value: "64" }
      )
    end

    it "analysis_debugが不完全でも落ちずにプレースホルダを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "analysis_debug" => {
            "spectral_balance" => nil,
            "cohesion_inputs" => { "balance" => "abc" }
          }
        }
      )

      sections = helper.singing_band_analysis_debug_sections(diagnosis)

      expect(sections.first[:items].find { |item| item[:label] == "RMS平均" }[:value]).to eq "-"
      expect(sections.second[:items].map { |item| item[:value] }).to eq ["-", "-", "-"]
      expect(sections.third[:items].find { |item| item[:label] == "音量バランス" }[:value]).to eq "-"
    end
  end

  describe "band payload check helpers" do
    it "development環境のbandでpayload確認を表示対象にすること" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "performance_type" => "band"
        }
      )

      expect(helper.singing_band_payload_check_visible?(diagnosis)).to eq true
    end

    it "production環境ではpayload確認を表示しないこと" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "performance_type" => "band"
        }
      )

      expect(helper.singing_band_payload_check_visible?(diagnosis)).to eq false
    end

    it "band以外にはpayload確認を表示しないこと" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
      diagnosis = build_diagnosis(
        performance_type: "vocal",
        result_payload: {
          "performance_type" => "vocal"
        }
      )

      expect(helper.singing_band_payload_check_visible?(diagnosis)).to eq false
    end

    it "band payload の必須キー確認を返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "performance_type" => "band",
          "overall_score" => 72,
          "pitch_score" => 68,
          "rhythm_score" => 65,
          "expression_score" => 70,
          "specific" => {
            "balance" => 64,
            "tightness" => 62,
            "groove" => 66,
            "role_clarity" => 63,
            "dynamics" => 67,
            "cohesion" => 65
          },
          "quality_flags" => {
            "too_short" => false,
            "too_quiet" => false,
            "too_loud" => false,
            "clipping_detected" => false,
            "mostly_silent" => false,
            "low_confidence" => false
          },
          "quality_message" => "",
          "analysis_debug" => {
            "rms_mean" => 0.123
          }
        }
      )

      items = helper.singing_band_payload_check_items(diagnosis)

      expect(items.find { |item| item[:label] == "specific.balance" }[:present]).to eq true
      expect(items.find { |item| item[:label] == "quality_flags.low_confidence" }[:present]).to eq true
      expect(items.find { |item| item[:label] == "analysis_debug.rms_mean" }[:present]).to eq true
    end

    it "missing key がある場合に検知できること" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "performance_type" => "band",
          "specific" => {
            "balance" => 64
          },
          "quality_flags" => {},
          "analysis_debug" => {}
        }
      )

      items = helper.singing_band_payload_check_items(diagnosis)

      expect(items.find { |item| item[:label] == "specific.cohesion" }[:present]).to eq false
      expect(items.find { |item| item[:label] == "specific.cohesion" }[:message]).to eq "⚠️ missing: specific.cohesion"
    end
  end

  describe "band quality notice helpers" do
    it "quality_messageがあればbandで表示対象にすること" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "quality_message" => "今回の音源は少し短めのため、診断結果は参考値としてご覧ください。"
        }
      )

      expect(helper.singing_band_quality_notice_visible?(diagnosis)).to eq true
      expect(helper.singing_band_quality_message(diagnosis)).to include "参考値"
    end

    it "quality_messageがなくてもlow_confidenceなら補完メッセージを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "quality_flags" => {
            "low_confidence" => true,
            "too_short" => true,
            "mostly_silent" => true
          }
        }
      )

      message = helper.singing_band_quality_message(diagnosis)

      expect(message).to include "参考値"
      expect(message).to include "30秒以上"
      expect(helper.singing_band_quality_notice_visible?(diagnosis)).to eq true
    end

    it "quality_flagsがnilでも落ちないこと" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "quality_flags" => nil
        }
      )

      expect(helper.singing_band_quality_flags(diagnosis)).to eq({})
      expect(helper.singing_band_quality_message(diagnosis)).to be_nil
      expect(helper.singing_band_quality_notice_visible?(diagnosis)).to eq false
    end

    it "band以外には注意メッセージを表示しないこと" do
      diagnosis = build_diagnosis(
        performance_type: "vocal",
        result_payload: {
          "quality_message" => "参考値としてご覧ください。"
        }
      )

      expect(helper.singing_band_quality_notice_visible?(diagnosis)).to eq false
    end
  end

  describe "#singing_common_score_cards" do
    it "vocalでは音程・リズム・表現を返すこと" do
      diagnosis = build_diagnosis(performance_type: "vocal")

      expect(helper.singing_common_score_cards(diagnosis).map { |card| card[:label] }).to eq ["音程", "リズム", "表現"]
    end

    it "drumsではpitch_scoreを表示対象から外しやすい構造になっていること" do
      diagnosis = build_diagnosis(performance_type: "drums")

      expect(helper.singing_common_score_cards(diagnosis).map { |card| card[:key] }).to eq [:rhythm_score, :expression_score]
    end

    it "bandでは調和・リズムの揃い・ダイナミクスを返すこと" do
      diagnosis = build_diagnosis(performance_type: "band")

      expect(helper.singing_common_score_cards(diagnosis).map { |card| card[:label] }).to eq ["調和", "リズムの揃い", "ダイナミクス"]
    end
  end

  describe "#singing_radar_chart_data" do
    it "vocalでは音程・リズム・表現のチャートデータを返すこと" do
      diagnosis = build_diagnosis(performance_type: "vocal", pitch_score: 82, rhythm_score: 76, expression_score: 84)

      data = helper.singing_radar_chart_data(diagnosis)

      expect(data.map { |item| item[:label] }).to eq ["音程", "リズム", "表現"]
      expect(data.map { |item| item[:score] }).to eq [82, 76, 84]
      expect(helper.singing_radar_chart_enabled?(diagnosis)).to eq true
    end

    it "guitarではギター向け5軸のチャートデータを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "guitar",
        rhythm_score: 71,
        expression_score: 69,
        result_payload: {
          "specific" => {
            "attack_score" => 74,
            "muting_score" => 68,
            "stability_score" => 72
          }
        }
      )

      data = helper.singing_radar_chart_data(diagnosis)

      expect(data.map { |item| item[:label] }).to eq ["リズム", "表現", "アタック", "ミュート", "安定感"]
      expect(data.map { |item| item[:score] }).to eq [71, 69, 74, 68, 72]
      expect(helper.singing_radar_chart_title(diagnosis)).to eq "ギター演奏の特徴バランス"
      expect(helper.singing_radar_chart_enabled?(diagnosis)).to eq true
    end

    it "guitarでspecificが不足して3軸未満の場合は表示対象にしないこと" do
      diagnosis = build_diagnosis(performance_type: "guitar", result_payload: {})

      expect(helper.singing_radar_chart_data(diagnosis).map { |item| item[:label] }).to eq ["リズム", "表現"]
      expect(helper.singing_radar_chart_enabled?(diagnosis)).to eq false
    end

    it "bassではベース向け5軸のチャートデータを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "bass",
        rhythm_score: 82,
        expression_score: 70,
        result_payload: {
          "specific" => {
            "groove_score" => 78,
            "note_length_score" => 69,
            "stability_score" => 74
          }
        }
      )

      data = helper.singing_radar_chart_data(diagnosis)

      expect(data.map { |item| item[:label] }).to eq ["リズム", "表現", "グルーヴ", "音価", "安定感"]
      expect(data.map { |item| item[:score] }).to eq [82, 70, 78, 69, 74]
      expect(helper.singing_radar_chart_title(diagnosis)).to eq "ベース演奏の特徴バランス"
      expect(helper.singing_radar_chart_description(diagnosis)).to include "ベース詳細スコア"
      expect(helper.singing_radar_chart_enabled?(diagnosis)).to eq true
    end

    it "bassでspecificが不足して3軸未満の場合は表示対象にしないこと" do
      diagnosis = build_diagnosis(performance_type: "bass", result_payload: {})

      expect(helper.singing_radar_chart_data(diagnosis).map { |item| item[:label] }).to eq ["リズム", "表現"]
      expect(helper.singing_radar_chart_enabled?(diagnosis)).to eq false
    end

    it "keyboardではキーボード向け7軸のチャートデータを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        pitch_score: 81,
        rhythm_score: 73,
        expression_score: 77,
        result_payload: {
          "specific" => {
            "chord_stability_score" => 78,
            "note_connection_score" => 70,
            "touch_score" => 66,
            "harmony_score" => 74
          }
        }
      )

      data = helper.singing_radar_chart_data(diagnosis)

      expect(data.map { |item| item[:label] }).to eq ["音程", "リズム", "表現", "コード安定", "音のつながり", "タッチ", "ハーモニー"]
      expect(data.map { |item| item[:score] }).to eq [81, 73, 77, 78, 70, 66, 74]
      expect(helper.singing_radar_chart_title(diagnosis)).to eq "キーボード演奏の特徴バランス"
      expect(helper.singing_radar_chart_description(diagnosis)).to include "キーボード詳細スコア"
      expect(helper.singing_radar_chart_enabled?(diagnosis)).to eq true
    end

    it "keyboardでspecificが不足しても共通3軸で安全に表示対象にすること" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        pitch_score: 81,
        rhythm_score: 73,
        expression_score: 77,
        result_payload: {}
      )

      data = helper.singing_radar_chart_data(diagnosis)

      expect(data.map { |item| item[:label] }).to eq ["音程", "リズム", "表現"]
      expect(data.map { |item| item[:score] }).to eq [81, 73, 77]
      expect(helper.singing_radar_chart_enabled?(diagnosis)).to eq true
    end

    it "keyboardでspecificの一部が不足しても取得できる軸だけで安全に返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        pitch_score: 81,
        rhythm_score: 73,
        expression_score: 77,
        result_payload: {
          "specific" => {
            "chord_stability_score" => 78,
            "harmony_score" => 74
          }
        }
      )

      data = helper.singing_radar_chart_data(diagnosis)

      expect(data.map { |item| item[:label] }).to eq ["音程", "リズム", "表現", "コード安定", "ハーモニー"]
      expect(data.map { |item| item[:score] }).to eq [81, 73, 77, 78, 74]
      expect(helper.singing_radar_chart_enabled?(diagnosis)).to eq true
    end

    it "未対応typeではチャートデータを返さないこと" do
      diagnosis = build_diagnosis(performance_type: "drums")

      expect(helper.singing_radar_chart_data(diagnosis)).to eq []
      expect(helper.singing_radar_chart_enabled?(diagnosis)).to eq false
    end

    it "bandではバンド向け7軸のチャートデータを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        pitch_score: 78,
        rhythm_score: 74,
        expression_score: 72,
        result_payload: {
          "specific" => {
            "role_understanding_score" => 70,
            "volume_balance_score" => 68,
            "groove_score" => 76,
            "cohesion_score" => 75
          }
        }
      )

      data = helper.singing_radar_chart_data(diagnosis)

      expect(data.map { |item| item[:label] }).to eq ["調和", "リズムの揃い", "ダイナミクス", "役割理解", "音量バランス", "グルーヴ", "全体のまとまり"]
      expect(helper.singing_radar_chart_title(diagnosis)).to eq "バンド演奏の特徴バランス"
      expect(helper.singing_radar_chart_description(diagnosis)).to include "バンド演奏詳細スコア"
    end
  end

  describe "#singing_practice_menus" do
    it "drumsではボーカル向けではなくドラム向け練習メニューを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "drums",
        result_payload: {
          "specific" => {
            "tempo_stability_score" => 62,
            "rhythm_precision_score" => 64,
            "dynamics_score" => 80,
            "fill_control_score" => 75
          }
        }
      )

      menus = helper.singing_practice_menus(diagnosis)

      expect(menus.map { |menu| menu[:title] }).to include "テンポキープ確認", "リズム粒そろえ練習"
      expect(menus.map { |menu| menu[:title] }).not_to include "ロングトーン安定練習"
    end

    it "keyboardではキーボード向けの弱点に合わせた練習メニューを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        rhythm_score: 82,
        expression_score: 78,
        pitch_score: 80,
        result_payload: {
          "specific" => {
            "chord_stability_score" => 62,
            "note_connection_score" => 66,
            "touch_score" => 80,
            "harmony_score" => 84
          }
        }
      )

      menus = helper.singing_practice_menus(diagnosis)
      menu_text = menus.map { |menu| [menu[:title], menu[:target], menu[:description]].join }.join

      expect(menus.map { |menu| menu[:title] }).to include "コードチェンジ安定練習", "フレーズ接続練習"
      expect(menu_text).to include "和音", "音の入り"
      expect(menu_text).not_to include "ピッキング"
      expect(menu_text).not_to include "ミュート"
      expect(menu_text).not_to include "フィル"
      expect(menu_text).not_to include "ストローク"
    end

    it "keyboardではcommon scoreの低さも練習メニューに反映すること" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        pitch_score: 64,
        rhythm_score: 63,
        expression_score: 62,
        result_payload: {
          "specific" => {
            "chord_stability_score" => 82,
            "note_connection_score" => 84,
            "touch_score" => 86,
            "harmony_score" => 88
          }
        }
      )

      menus = helper.singing_practice_menus(diagnosis)

      expect(menus.map { |menu| menu[:title] }).to include "メトロノーム伴奏練習", "強弱づけ練習", "音選びと和音確認"
      expect(menus.size).to be <= 3
    end

    it "keyboardでspecificがない場合もcommon scoreから安全に提案すること" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        rhythm_score: 65,
        expression_score: 82,
        pitch_score: 84,
        result_payload: {}
      )

      menus = helper.singing_practice_menus(diagnosis)

      expect(menus.map { |menu| menu[:title] }).to include "メトロノーム伴奏練習"
      expect(menus.map { |menu| menu[:title] }).not_to include "コードチェンジ安定練習"
    end

    it "keyboardでspecificが一部欠損していても取得できる項目だけで提案すること" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        rhythm_score: 82,
        expression_score: 82,
        pitch_score: 82,
        result_payload: {
          "specific" => {
            "touch_score" => 61
          }
        }
      )

      menus = helper.singing_practice_menus(diagnosis)

      expect(menus.map { |menu| menu[:title] }).to include "打鍵の粒そろえ練習"
      expect(menus.map { |menu| menu[:title] }).not_to include "コードチェンジ安定練習"
    end

    it "bandではバンド向け練習メニューを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        rhythm_score: 64,
        expression_score: 78,
        result_payload: {
          "specific" => {
            "ensemble_score" => 62,
            "role_understanding_score" => 66,
            "volume_balance_score" => 61,
            "rhythm_unity_score" => 63
          }
        }
      )

      menus = helper.singing_practice_menus(diagnosis)

      expect(menus.map { |menu| menu[:title] }).to include "短区間アンサンブル確認", "役割分担の見直し", "音量バランス調整"
      expect(menus.map { |menu| menu[:description] }.join).to include("全員", "主役", "音量")
      expect(menus.map { |menu| menu[:description] }.join).not_to include("ロングトーン", "ピッキング", "打鍵")
    end
  end

  describe "#singing_advanced_feedback_available?" do
    it "vocalとguitarとbassとdrumsとkeyboardとbandを詳細フィードバックカードの表示対象にすること" do
      expect(helper.singing_advanced_feedback_available?(build_diagnosis(performance_type: "vocal"))).to eq true
      expect(helper.singing_advanced_feedback_available?(build_diagnosis(performance_type: "guitar"))).to eq true
      expect(helper.singing_advanced_feedback_available?(build_diagnosis(performance_type: "bass"))).to eq true
      expect(helper.singing_advanced_feedback_available?(build_diagnosis(performance_type: "drums"))).to eq true
      expect(helper.singing_advanced_feedback_available?(build_diagnosis(performance_type: "keyboard"))).to eq true
      expect(helper.singing_advanced_feedback_available?(build_diagnosis(performance_type: "band"))).to eq true
      expect(helper.singing_advanced_feedback_lead(build_diagnosis(performance_type: "guitar"))).to include "アタック・ミュート・安定感"
      expect(helper.singing_advanced_feedback_lead(build_diagnosis(performance_type: "bass"))).to include "グルーヴ・音価・安定感"
      expect(helper.singing_advanced_feedback_lead(build_diagnosis(performance_type: "drums"))).to include "テンポ安定・リズム精度・ダイナミクス"
      expect(helper.singing_advanced_feedback_lead(build_diagnosis(performance_type: "keyboard"))).to include "和音の安定・音のつながり・タッチ"
      expect(helper.singing_advanced_feedback_lead(build_diagnosis(performance_type: "band"))).to include "アンサンブル力・役割理解・音量バランス"
    end
  end

  describe "#singing_premium_type_diagnosis_cards" do
    it "guitarではギター固有の詳細診断カードを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "guitar",
        result_payload: {
          "specific" => {
            "attack_score" => 84,
            "muting_score" => 68,
            "stability_score" => 72
          }
        }
      )

      cards = helper.singing_premium_type_diagnosis_cards(diagnosis)

      expect(cards.map { |card| card[:label] }).to eq(["発音の輪郭", "余韻の整理", "演奏の芯"])
      expect(cards.first[:insight]).to include("立ち上がり")
      expect(cards.map { |card| card[:insight] }.join).not_to include("グルーヴ")
      expect(cards.map { |card| card[:insight] }.join).not_to include("ハーモニー")
    end

    it "bassではベース固有の詳細診断カードを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "bass",
        result_payload: {
          "specific" => {
            "groove_score" => 84,
            "note_length_score" => 68,
            "stability_score" => 72
          }
        }
      )

      cards = helper.singing_premium_type_diagnosis_cards(diagnosis)

      expect(cards.map { |card| card[:label] }).to eq(["ノリの土台", "音価コントロール", "低音の支え"])
      expect(cards.first[:insight]).to include("低音")
      expect(cards.map { |card| card[:insight] }.join).not_to include("コード")
      expect(cards.map { |card| card[:insight] }.join).not_to include("フィル")
    end

    it "drumsではドラム固有の詳細診断カードを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "drums",
        result_payload: {
          "specific" => {
            "tempo_stability_score" => 84,
            "rhythm_precision_score" => 68,
            "fill_control_score" => 72
          }
        }
      )

      cards = helper.singing_premium_type_diagnosis_cards(diagnosis)

      expect(cards.map { |card| card[:label] }).to eq(["テンポの支え", "リズムの芯", "展開のまとまり"])
      expect(cards.first[:insight]).to include("ビート")
      expect(cards.map { |card| card[:insight] }.join).not_to include("ハーモニー")
      expect(cards.map { |card| card[:insight] }.join).not_to include("コード")
    end

    it "keyboardではキーボード固有の詳細診断カードを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        result_payload: {
          "specific" => {
            "chord_stability_score" => 84,
            "note_connection_score" => 68,
            "touch_score" => 72
          }
        }
      )

      cards = helper.singing_premium_type_diagnosis_cards(diagnosis)

      expect(cards.map { |card| card[:label] }).to eq(["和音の安定", "音のつながり", "タッチと響き"])
      expect(cards.first[:insight]).to include("和音")
      expect(cards.map { |card| card[:insight] }.join).not_to include("フィル")
      expect(cards.map { |card| card[:insight] }.join).not_to include("グルーヴ")
    end

    it "specificが不足していても例外なくカードを返すこと" do
      diagnosis = build_diagnosis(performance_type: "guitar", result_payload: nil)

      expect { helper.singing_premium_type_diagnosis_cards(diagnosis) }.not_to raise_error
      expect(helper.singing_premium_type_diagnosis_cards(diagnosis).size).to eq 3
    end
  end

  describe "premium type diagnosis presentation helpers" do
    it "performance_typeごとのアクセントキーとアイコンを返すこと" do
      expect(helper.singing_premium_type_diagnosis_accent_key(build_diagnosis(performance_type: "guitar"))).to eq("guitar")
      expect(helper.singing_premium_type_diagnosis_icon(build_diagnosis(performance_type: "guitar"))).to eq("🎸")
      expect(helper.singing_premium_type_diagnosis_icon(build_diagnosis(performance_type: "bass"))).to eq("🎵")
      expect(helper.singing_premium_type_diagnosis_icon(build_diagnosis(performance_type: "drums"))).to eq("🥁")
      expect(helper.singing_premium_type_diagnosis_icon(build_diagnosis(performance_type: "keyboard"))).to eq("🎹")
      expect(helper.singing_premium_type_diagnosis_icon(build_diagnosis(performance_type: "vocal"))).to eq("🎤")
    end

    it "performance_typeごとの専用タイトルを返すこと" do
      expect(helper.singing_premium_type_diagnosis_title(build_diagnosis(performance_type: "guitar"))).to eq("ギター演奏の深掘り診断")
      expect(helper.singing_premium_type_diagnosis_title(build_diagnosis(performance_type: "bass"))).to eq("ベース演奏の土台診断")
      expect(helper.singing_premium_type_diagnosis_title(build_diagnosis(performance_type: "drums"))).to eq("ドラム演奏のリズム診断")
      expect(helper.singing_premium_type_diagnosis_title(build_diagnosis(performance_type: "keyboard"))).to eq("キーボード演奏の響き診断")
      expect(helper.singing_premium_type_diagnosis_title(build_diagnosis(performance_type: "vocal"))).to eq("歌唱の深掘り診断")
    end

    it "非Premium向けロック文言にパート別の専用感があること" do
      expect(helper.singing_premium_type_diagnosis_locked_lead(build_diagnosis(performance_type: "guitar"))).to include("発音・ミュート・安定感")
      expect(helper.singing_premium_type_diagnosis_locked_lead(build_diagnosis(performance_type: "bass"))).to include("グルーヴ・音価・土台感")
      expect(helper.singing_premium_type_diagnosis_locked_lead(build_diagnosis(performance_type: "drums"))).to include("テンポ・リズム・フィル")
      expect(helper.singing_premium_type_diagnosis_locked_lead(build_diagnosis(performance_type: "keyboard"))).to include("和音・タッチ・響き")
    end
  end

  describe "#singing_growth_chart_data" do
    it "日付順のグラフデータを返すこと" do
      diagnoses = [
        build_diagnosis(overall_score: 62, pitch_score: 58, rhythm_score: 64, expression_score: 60, created_at: Time.zone.parse("2026-04-01 10:00:00")),
        build_diagnosis(overall_score: 74, pitch_score: 70, rhythm_score: 76, expression_score: 72, created_at: Time.zone.parse("2026-04-10 10:00:00")),
        build_diagnosis(overall_score: 81, pitch_score: 79, rhythm_score: 83, expression_score: 78, created_at: Time.zone.parse("2026-04-20 10:00:00"))
      ]

      data = helper.singing_growth_chart_data(diagnoses)

      expect(data.map { |item| item[:label] }).to eq(%w[04/01 04/10 04/20])
      expect(data.map { |item| item[:overall_score] }).to eq([62, 74, 81])
    end

    it "completedでない診断は対象外にできること" do
      diagnoses = [
        build_diagnosis(overall_score: 62, created_at: Time.zone.parse("2026-04-01 10:00:00"), completed: true),
        build_diagnosis(overall_score: 10, created_at: Time.zone.parse("2026-04-05 10:00:00"), completed: false),
        build_diagnosis(overall_score: 81, created_at: Time.zone.parse("2026-04-20 10:00:00"), completed: true)
      ]

      data = helper.singing_growth_chart_data(diagnoses)

      expect(data.map { |item| item[:overall_score] }).to eq([62, 81])
    end

    it "1件だけでも安全に動くこと" do
      diagnoses = [build_diagnosis(created_at: Time.zone.parse("2026-04-20 10:00:00"))]

      expect(helper.singing_growth_chart_enabled?(diagnoses)).to eq(false)
      expect(helper.singing_growth_chart_lead(build_diagnosis(performance_type: "guitar"), diagnoses)).to include("次回以降")
      expect(helper.singing_growth_chart_data(diagnoses).size).to eq(1)
    end

    it "グラフ系列定義を返すこと" do
      series = helper.singing_growth_chart_series(build_diagnosis(performance_type: "bass"))

      expect(series.map { |item| item[:key] }).to eq([:overall_score, :pitch_score, :rhythm_score, :expression_score])
      expect(series.map { |item| item[:label] }).to eq(["総合", "音程", "リズム", "表現"])
    end
  end

  describe "#singing_specific_growth_chart_data" do
    it "performance_typeごとのspecific系列を返すこと" do
      diagnoses = [
        build_diagnosis(
          performance_type: "guitar",
          result_payload: { "specific" => { "attack_score" => 62, "muting_score" => 71, "stability_score" => 68 } },
          created_at: Time.zone.parse("2026-04-01 10:00:00")
        ),
        build_diagnosis(
          performance_type: "guitar",
          result_payload: { "specific" => { "attack_score" => 78, "muting_score" => 75, "stability_score" => 73 } },
          created_at: Time.zone.parse("2026-04-20 10:00:00")
        )
      ]
      diagnosis = build_diagnosis(performance_type: "guitar")

      series = helper.singing_specific_growth_chart_series(diagnosis, diagnoses)
      data = helper.singing_specific_growth_chart_data(diagnosis, diagnoses)

      expect(series.map { |item| item[:label] }).to eq(["アタック", "ミュート", "安定感"])
      expect(data.map { |item| item[:attack_score] }).to eq([62, 78])
      expect(helper.singing_specific_growth_chart_enabled?(diagnoses, diagnosis)).to eq(true)
    end

    it "specific欠損があっても安全に動くこと" do
      diagnoses = [
        build_diagnosis(
          performance_type: "keyboard",
          result_payload: { "specific" => { "touch_score" => 66 } },
          created_at: Time.zone.parse("2026-04-01 10:00:00")
        ),
        build_diagnosis(
          performance_type: "keyboard",
          result_payload: {},
          created_at: Time.zone.parse("2026-04-20 10:00:00")
        )
      ]
      diagnosis = build_diagnosis(performance_type: "keyboard")

      expect { helper.singing_specific_growth_chart_series(diagnosis, diagnoses) }.not_to raise_error
      expect { helper.singing_specific_growth_chart_data(diagnosis, diagnoses) }.not_to raise_error
      expect(helper.singing_specific_growth_chart_series(diagnosis, diagnoses).map { |item| item[:label] }).to eq(["タッチ"])
      expect(helper.singing_specific_growth_chart_data(diagnosis, diagnoses).last[:touch_score]).to eq(nil)
    end

    it "performance_typeごとに系列色を返すこと" do
      diagnosis = build_diagnosis(performance_type: "drums")
      diagnoses = [
        build_diagnosis(
          performance_type: "drums",
          result_payload: { "specific" => { "tempo_stability_score" => 70, "rhythm_precision_score" => 68, "dynamics_score" => 65, "fill_control_score" => 64 } }
        ),
        build_diagnosis(
          performance_type: "drums",
          result_payload: { "specific" => { "tempo_stability_score" => 74, "rhythm_precision_score" => 72, "dynamics_score" => 67, "fill_control_score" => 69 } }
        )
      ]

      series = helper.singing_specific_growth_chart_series(diagnosis, diagnoses)

      expect(series.map { |item| item[:color] }).to eq(["#2563eb", "#7c3aed", "#ea580c", "#dc2626"])
    end

    it "非Premium導線用の文言を返すこと" do
      expect(helper.singing_specific_growth_chart_locked_lead(build_diagnosis(performance_type: "bass"))).to include("グルーヴ・音価・安定感")
    end
  end

  describe "#singing_specific_growth_summary_cards" do
    it "履歴2件以上で伸びている項目・強み・改善ポイントを返すこと" do
      diagnoses = [
        build_diagnosis(
          performance_type: "keyboard",
          result_payload: { "specific" => { "touch_score" => 58, "harmony_score" => 74, "note_connection_score" => 63 } },
          created_at: Time.zone.parse("2026-04-01 10:00:00")
        ),
        build_diagnosis(
          performance_type: "keyboard",
          result_payload: { "specific" => { "touch_score" => 71, "harmony_score" => 80, "note_connection_score" => 60 } },
          created_at: Time.zone.parse("2026-04-20 10:00:00")
        )
      ]
      diagnosis = build_diagnosis(performance_type: "keyboard")

      cards = helper.singing_specific_growth_summary_cards(diagnosis, diagnoses)

      expect(cards.map { |item| item[:label] }).to include("最近伸びている項目", "今の強み", "次の改善ポイント")
      expect(cards.map { |item| item[:title] }).to include("タッチ", "ハーモニー", "音のつながり")
      expect(cards.find { |item| item[:label] == "最近伸びている項目" }[:body]).to include("タッチ")
    end

    it "履歴1件以下では空を返すこと" do
      diagnosis = build_diagnosis(performance_type: "guitar")
      diagnoses = [build_diagnosis(performance_type: "guitar")]

      expect(helper.singing_specific_growth_summary_cards(diagnosis, diagnoses)).to eq([])
      expect(helper.singing_specific_growth_summary_lead(diagnosis, diagnoses)).to include("次回以降")
    end

    it "specific欠損でも落ちないこと" do
      diagnosis = build_diagnosis(performance_type: "bass")
      diagnoses = [
        build_diagnosis(performance_type: "bass", result_payload: {}, created_at: Time.zone.parse("2026-04-01 10:00:00")),
        build_diagnosis(performance_type: "bass", result_payload: { "specific" => { "groove_score" => 70 } }, created_at: Time.zone.parse("2026-04-20 10:00:00"))
      ]

      expect { helper.singing_specific_growth_summary_cards(diagnosis, diagnoses) }.not_to raise_error
    end

    it "欠損がある場合は補足文を返すこと" do
      diagnosis = build_diagnosis(performance_type: "keyboard")
      diagnoses = [
        build_diagnosis(
          performance_type: "keyboard",
          result_payload: { "specific" => { "touch_score" => 66 } },
          created_at: Time.zone.parse("2026-04-01 10:00:00")
        ),
        build_diagnosis(
          performance_type: "keyboard",
          result_payload: { "specific" => { "touch_score" => 72, "harmony_score" => 70 } },
          created_at: Time.zone.parse("2026-04-20 10:00:00")
        )
      ]

      expect(helper.singing_specific_growth_chart_note(diagnosis, diagnoses)).to include("線が途中で途切れる")
    end
  end

  describe "#singing_history_growth_hint" do
    let(:premium_customer) { instance_double(Customer, has_feature?: true) }
    let(:non_premium_customer) { instance_double(Customer, has_feature?: false) }

    it "前回より伸びている項目を返すこと" do
      diagnosis = build_diagnosis(
        score_comparison: {
          overall_score: { delta: 2 },
          pitch_score: { delta: 1 },
          rhythm_score: { delta: 5 },
          expression_score: { delta: 3 }
        }
      )

      expect(helper.singing_history_growth_label(diagnosis)).to eq("最近の伸び")
      expect(helper.singing_history_growth_hint(diagnosis)).to eq("前回よりリズムが伸びています")
    end

    it "Premiumではspecific由来の成長ヒントを優先すること" do
      diagnosis = build_diagnosis(
        performance_type: "guitar",
        specific_comparison: {
          attack_score: { delta: 4 },
          muting_score: { delta: 1 },
          stability_score: { delta: 2 }
        },
        score_comparison: {
          overall_score: { delta: 5 },
          pitch_score: { delta: 2 },
          rhythm_score: { delta: 1 },
          expression_score: { delta: 3 }
        }
      )

      expect(helper.singing_history_growth_hint(diagnosis, premium_customer)).to eq("前回よりアタックが伸びています")
    end

    it "非Premiumでは共通スコア由来のヒントを維持すること" do
      diagnosis = build_diagnosis(
        performance_type: "bass",
        specific_comparison: {
          groove_score: { delta: 4 },
          note_length_score: { delta: 1 },
          stability_score: { delta: 2 }
        },
        score_comparison: {
          overall_score: { delta: 1 },
          pitch_score: { delta: 0 },
          rhythm_score: { delta: 3 },
          expression_score: { delta: 2 }
        }
      )

      expect(helper.singing_history_growth_hint(diagnosis, non_premium_customer)).to eq("前回よりリズムが伸びています")
    end

    it "Premiumでもspecific比較がない場合は共通スコアへフォールバックすること" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        specific_comparison: nil,
        score_comparison: {
          overall_score: { delta: 1 },
          pitch_score: { delta: 2 },
          rhythm_score: { delta: 1 },
          expression_score: { delta: 0 }
        }
      )

      expect(helper.singing_history_growth_hint(diagnosis, premium_customer)).to eq("前回より音程が伸びています")
    end

    it "performance_typeごとの自然なspecific文言を返すこと" do
      vocal = build_diagnosis(performance_type: "vocal", specific_comparison: { pronunciation_score: { delta: 2 } })
      drums = build_diagnosis(performance_type: "drums", specific_comparison: { tempo_stability_score: { delta: 2 } })
      keyboard = build_diagnosis(performance_type: "keyboard", specific_comparison: { touch_score: { delta: 2 } })

      expect(helper.singing_history_growth_hint(vocal, premium_customer)).to eq("発音が安定してきています")
      expect(helper.singing_history_growth_hint(drums, premium_customer)).to eq("テンポ安定が伸びています")
      expect(helper.singing_history_growth_hint(keyboard, premium_customer)).to eq("タッチが整ってきています")
    end

    it "総合スコアの伸びを優先して返せること" do
      diagnosis = build_diagnosis(
        score_comparison: {
          overall_score: { delta: 4 },
          pitch_score: { delta: 2 },
          rhythm_score: { delta: 1 },
          expression_score: { delta: 3 }
        }
      )

      expect(helper.singing_history_growth_hint(diagnosis)).to eq("今回は総合スコアが上がっています")
    end

    it "比較対象がない場合は案内文を返すこと" do
      diagnosis = build_diagnosis(score_comparison: nil)

      expect(helper.singing_history_growth_hint(diagnosis)).to eq("次回以降、成長傾向が表示されます")
    end

    it "nilやマイナス差分でも落ちないこと" do
      diagnosis = build_diagnosis(
        score_comparison: {
          overall_score: { delta: nil },
          pitch_score: { delta: -1 },
          rhythm_score: { delta: 0 },
          expression_score: { delta: nil }
        }
      )

      expect { helper.singing_history_growth_hint(diagnosis) }.not_to raise_error
      expect(helper.singing_history_growth_hint(diagnosis)).to include("安定して積み上がっています")
    end

    it "未完了診断では案内文を返すこと" do
      diagnosis = build_diagnosis(completed: false)

      expect(helper.singing_history_growth_hint(diagnosis)).to eq("次回以降、成長傾向が表示されます")
    end
  end

  describe "weekly coach helpers" do
    let(:premium_customer) { instance_double(Customer, has_feature?: true) }
    let(:non_premium_customer) { instance_double(Customer, has_feature?: false) }

    it "Premium向け週間アドバイスを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "guitar",
        result_payload: { "specific" => { "attack_score" => 58, "muting_score" => 72, "stability_score" => 70 } },
        specific_comparison: {
          attack_score: { delta: -3 },
          muting_score: { delta: 1 },
          stability_score: { delta: 0 }
        }
      )

      expect(helper.singing_weekly_coach_available?(premium_customer)).to eq(true)
      expect(helper.singing_weekly_coach_title(diagnosis)).to include("今週の練習テーマ")

      card = helper.singing_weekly_coach_card(diagnosis)

      expect(card[:theme]).to include("アタック")
      expect(card[:focus]).to include("音の出だし")
      expect(card[:practice_title]).to eq("ピッキングの立ち上がり確認")
      expect(card[:encouragement]).to include("説得力")
    end

    it "非Premiumではロック導線用の文言を返すこと" do
      diagnosis = build_diagnosis(performance_type: "keyboard")

      expect(helper.singing_weekly_coach_available?(non_premium_customer)).to eq(false)
      expect(helper.singing_weekly_coach_locked_lead(diagnosis)).to include("今週の練習テーマ")
    end

    it "performance_typeごとの自然な文言を返すこと" do
      bass = build_diagnosis(performance_type: "bass", result_payload: { "specific" => { "groove_score" => 55 } })
      drums = build_diagnosis(performance_type: "drums", result_payload: { "specific" => { "tempo_stability_score" => 56 } })
      keyboard = build_diagnosis(performance_type: "keyboard", result_payload: { "specific" => { "touch_score" => 54 } })
      vocal = build_diagnosis(performance_type: "vocal", result_payload: { "specific" => { "pronunciation_score" => 53 } })
      band = build_diagnosis(performance_type: "band", result_payload: { "specific" => { "balance" => 52 } })

      expect(helper.singing_weekly_coach_card(bass)[:theme]).to include("グルーヴ")
      expect(helper.singing_weekly_coach_card(drums)[:theme]).to include("テンポ")
      expect(helper.singing_weekly_coach_card(keyboard)[:theme]).to include("タッチ")
      expect(helper.singing_weekly_coach_card(vocal)[:theme]).to include("発音")
      expect(helper.singing_weekly_coach_card(band)[:theme]).to include("音量バランス")
    end

    it "bandの週間アドバイスが表示向け項目を返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "specific" => {
            "balance" => 58,
            "tightness" => 66,
            "groove" => 64,
            "role_clarity" => 70,
            "dynamics" => 68,
            "cohesion" => 69
          }
        }
      )

      card = helper.singing_weekly_coach_card(diagnosis)

      expect(card[:theme]).to include("音量バランス")
      expect(card[:goal]).to include("曲として聴こえる音量")
      expect(card[:studio_steps]).to be_present
      expect(card[:recording_points]).to be_present
      expect(card[:homework]).to be_present
    end

    it "bandで最低スコアがbalanceの場合は音量バランス系テーマになること" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "specific" => {
            "balance" => 51,
            "tightness" => 70,
            "groove" => 68,
            "role_clarity" => 69,
            "dynamics" => 67,
            "cohesion" => 72
          }
        }
      )

      expect(helper.singing_weekly_coach_card(diagnosis)[:theme]).to include("音量バランス")
    end

    it "bandで最低スコアがtightnessの場合はリズム系テーマになること" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "specific" => {
            "balance" => 67,
            "tightness" => 49,
            "groove" => 68,
            "role_clarity" => 69,
            "dynamics" => 70,
            "cohesion" => 72
          }
        }
      )

      expect(helper.singing_weekly_coach_card(diagnosis)[:theme]).to include("リズム隊")
    end

    it "bandでlow_confidenceがtrueの場合は参考値メッセージを含むこと" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "specific" => {
            "balance" => 60,
            "tightness" => 58
          },
          "quality_flags" => {
            "low_confidence" => true
          }
        }
      )

      expect(helper.singing_weekly_coach_card(diagnosis)[:quality_note]).to include("参考値")
      expect(helper.singing_weekly_coach_card(diagnosis)[:quality_note]).to include("30秒以上")
    end

    it "bandでspecificがnilでも落ちないこと" do
      diagnosis = build_diagnosis(
        performance_type: "band",
        result_payload: {
          "specific" => nil
        }
      )

      expect { helper.singing_weekly_coach_card(diagnosis) }.not_to raise_error
      expect(helper.singing_weekly_coach_card(diagnosis)[:theme]).to be_present
    end

    it "specific欠損でも共通スコアから安全に返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "keyboard",
        overall_score: 68,
        pitch_score: 72,
        rhythm_score: 48,
        expression_score: 61,
        result_payload: {}
      )

      expect { helper.singing_weekly_coach_card(diagnosis) }.not_to raise_error
      expect(helper.singing_weekly_coach_card(diagnosis)[:theme]).to include("リズム")
    end

    it "reference_comparisonがある場合は曲基準メモを返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "drums",
        result_payload: { "specific" => { "tempo_stability_score" => 58 } },
        reference_comparison: {
          tempo_match_level: "far",
          bpm_diff: 6,
          reference_bpm: 120,
          estimated_bpm: 126
        }
      )

      card = helper.singing_weekly_coach_card(diagnosis)

      expect(card[:reference_note]).to include("曲基準メモ")
      expect(card[:reference_note]).to include("テンポ感")
      expect(card[:reference_note]).to include("クリック")
    end

    it "テンポズレが大きいときは週間テーマをリズム寄りへ少し寄せること" do
      diagnosis = build_diagnosis(
        performance_type: "drums",
        result_payload: { "specific" => { "dynamics_score" => 40, "tempo_stability_score" => 70 } },
        reference_comparison: {
          tempo_match_level: "far",
          reference_bpm: 120,
          estimated_bpm: 128,
          bpm_diff: 8
        }
      )

      card = helper.singing_weekly_coach_card(diagnosis)

      expect(card[:theme]).to include("テンポ")
      expect(card[:focus]).to include("参考テンポ")
    end

    it "reference判定バッジの見た目用クラスと文言を返すこと" do
      expect(helper.singing_reference_match_badge_label("exact")).to eq("かなり近い")
      expect(helper.singing_reference_match_badge_label("far")).to eq("離れ気味")
      expect(helper.singing_reference_match_badge_class("close")).to include("good")
      expect(helper.singing_reference_match_badge_class("moderate")).to include("caution")
      expect(helper.singing_reference_match_badge_class("unknown")).to include("muted")
    end

    it "keyズレがある場合は音程や音選び系の補足を返すこと" do
      diagnosis = build_diagnosis(
        performance_type: "vocal",
        result_payload: { "specific" => { "pronunciation_score" => 53 } },
        reference_comparison: {
          key_match_level: "far",
          reference_key: "A",
          estimated_key: "C"
        }
      )

      expect(helper.singing_weekly_coach_card(diagnosis)[:reference_note]).to include("ガイド音")
      expect(helper.singing_weekly_coach_card(diagnosis)[:reference_note]).to include("キー")
    end

    it "reference_comparisonがなくても従来どおり動くこと" do
      diagnosis = build_diagnosis(
        performance_type: "guitar",
        result_payload: { "specific" => { "attack_score" => 58 } },
        reference_comparison: nil
      )

      expect(helper.singing_weekly_coach_card(diagnosis)[:reference_note]).to be_nil
      expect(helper.singing_weekly_coach_card(diagnosis)[:theme]).to include("アタック")
    end
  end

  def build_diagnosis(overall_score: 75, pitch_score: 75, rhythm_score: 75, expression_score: 75, result_payload: {}, performance_type: "vocal", specific_comparison: nil, reference_comparison: nil, score_comparison: nil, created_at: nil, completed: true)
    Struct.new(:overall_score, :pitch_score, :rhythm_score, :expression_score, :result_payload, :performance_type, :specific_comparison_value, :reference_comparison_value, :score_comparison_value, :created_at, :completed_value) do
      def performance_type_label
        {
          "vocal" => "ボーカル",
          "guitar" => "ギター",
          "bass" => "ベース",
          "drums" => "ドラム",
          "keyboard" => "キーボード",
          "band" => "バンド演奏"
        }.fetch(performance_type, "ボーカル")
      end

      def specific_score_comparison
        specific_comparison_value
      end

      def reference_comparison
        reference_comparison_value
      end

      def score_comparison
        score_comparison_value
      end

      def completed?
        completed_value
      end

      def performance_type_vocal?
        performance_type == "vocal"
      end

      def performance_type_guitar?
        performance_type == "guitar"
      end

      def performance_type_bass?
        performance_type == "bass"
      end

      def performance_type_drums?
        performance_type == "drums"
      end

      def performance_type_keyboard?
        performance_type == "keyboard"
      end

      def performance_type_band?
        performance_type == "band"
      end
    end.new(overall_score, pitch_score, rhythm_score, expression_score, result_payload, performance_type, specific_comparison, reference_comparison, score_comparison, created_at, completed)
  end
end
