require 'rails_helper'

RSpec.describe SingingDiagnoses::AiCommentGenerator do
  describe ".call" do
    it "詳細フィードバックとスコアをOpenAI clientへ渡してコメントを生成すること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        song_title: "Sample Song",
        overall_score: 82,
        pitch_score: 88,
        rhythm_score: 74,
        expression_score: 69
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "AIからの練習コメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to eq "AIからの練習コメントです。"
      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(args[:instructions]).to include("歌唱・演奏の練習を支援するコーチ")
        expect(input["song_title"]).to eq "Sample Song"
        expect(input["performance_type"]).to eq "vocal"
        expect(input["result_payload"]).to be_present
        expect(input["scores"]).to include("pitch" => 88)
      end
    end

    it "前回比較がある場合は差分に触れること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        overall_score: 70,
        pitch_score: 70,
        rhythm_score: 70,
        expression_score: 70,
        created_at: 1.day.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        overall_score: 76,
        pitch_score: 74,
        rhythm_score: 70,
        expression_score: 80,
        created_at: Time.current
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "前回比も踏まえたコメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to include("前回比")
      expect(client).to have_received(:generate_text) do |args|
        expect(args[:input]).to include("+4")
        expect(args[:input]).to include("+10")
      end
    end

    it "曲基準比較がある場合はAIコメント生成入力へ渡すこと" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        song_title: "Reference Song",
        overall_score: 82,
        pitch_score: 88,
        rhythm_score: 74,
        expression_score: 69,
        result_payload: {
          schema_version: 1,
          performance_type: "vocal",
          common: {
            overall_score: 82,
            pitch_score: 88,
            rhythm_score: 74,
            expression_score: 69
          },
          specific: {},
          reference_comparison: {
            reference_key: "A",
            estimated_key: "A",
            key_match_level: "exact",
            reference_bpm: 120.0,
            estimated_bpm: 118.5,
            bpm_diff: 1.5,
            tempo_match_level: "close"
          }
        }
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "曲基準も踏まえたコメントです。"
      )

      described_class.call(diagnosis, client: client)

      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(args[:instructions]).to include("reference_comparison")
        expect(args[:instructions]).to include("曲のキーやテンポ")
        expect(input["reference_comparison"]).to include(
          "reference_key" => "A",
          "estimated_key" => "A",
          "key_match_level" => "exact",
          "reference_bpm" => 120.0,
          "estimated_bpm" => 118.5,
          "bpm_diff" => 1.5,
          "tempo_match_level" => "close"
        )
        expect(input.dig("reference_context", "summary")).to include("参考キーA")
        expect(input.dig("reference_context", "summary")).to include("参考テンポ120.0BPM")
        expect(input.dig("reference_context", "key_guidance")).to include("曲の中心")
        expect(input.dig("reference_context", "tempo_guidance")).to include("曲の流れ")
        expect(input.dig("weekly_coach_context", "reference_note")).to be_present
      end
    end

    it "曲基準比較がない場合も空の入力として安全に扱うこと" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        result_payload: nil
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "通常コメントです。"
      )

      described_class.call(diagnosis, client: client)

      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(input["reference_comparison"]).to eq({})
        expect(input["reference_context"]).to eq({})
        expect(input["weekly_coach_context"]).to include("theme", "focus", "practice_title")
        expect(input.dig("weekly_coach_context", "reference_note")).to be_nil
      end
    end

    it "specificスコアとspecific前回比をOpenAI clientへ渡すこと" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        overall_score: 70,
        pitch_score: 70,
        rhythm_score: 70,
        expression_score: 70,
        result_payload: {
          specific: {
            volume_score: 70,
            pronunciation_score: 80,
            relax_score: 65
          }
        },
        created_at: 1.day.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        overall_score: 76,
        pitch_score: 74,
        rhythm_score: 70,
        expression_score: 80,
        result_payload: {
          schema_version: 1,
          performance_type: "vocal",
          common: {
            overall_score: 76,
            pitch_score: 74,
            rhythm_score: 70,
            expression_score: 80
          },
          specific: {
            volume_score: 73,
            pronunciation_score: 78,
            mix_voice_score: 69
          }
        },
        created_at: Time.current
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "詳細スコアも踏まえたコメントです。"
      )

      described_class.call(diagnosis, client: client)

      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(input["specific_scores"].map { |score| score["label"] }).to include("声量", "発音", "ミックスボイス")
        expect(input["specific_comparison"]).to contain_exactly(
          include("label" => "声量", "delta" => "+3"),
          include("label" => "発音", "delta" => "-2")
        )
      end
    end

    it "guitarでは専用promptと詳細なコメント生成入力を作ること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        performance_type: :guitar,
        overall_score: 78,
        pitch_score: 72,
        rhythm_score: 80,
        expression_score: 75,
        result_payload: {
          schema_version: 1,
          performance_type: "guitar",
          common: {
            overall_score: 78,
            pitch_score: 72,
            rhythm_score: 80,
            expression_score: 75
          },
          specific: {
            attack_score: 74,
            muting_score: 68,
            stability_score: 72
          }
        }
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "ギター向けコメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to eq "ギター向けコメントです。"
      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(args[:instructions]).to include("guitarでは")
        expect(args[:instructions]).to include("アタック、ミュート、安定感")
        expect(args[:instructions]).to include("vocal固有")
        expect(args[:instructions]).to include("喉")
        expect(args[:instructions]).to include("次に意識する練習")
        expect(input["performance_type"]).to eq "guitar"
        expect(input["performance_type_label"]).to eq "ギター"
        expect(input["specific_scores"]).to include(include("label" => "アタック"))
        expect(input["specific_scores"]).to include(include("label" => "ミュート"))
        expect(input["specific_scores"]).to include(include("label" => "安定感"))
        expect(input["advanced_feedback"].map { |feedback| feedback["label"] }).to include("アタック", "ミュート", "安定感", "全体のまとまり")
        expect(input.dig("guitar_context", "specific_scores")).to include(
          "attack_score" => 74,
          "muting_score" => 68,
          "stability_score" => 72
        )
        expect(input.dig("guitar_context", "focus_points")).to include("フレーズの輪郭")
        expect(args[:max_output_tokens]).to eq 500
      end
    end

    it "guitarではspecific比較をコメント生成入力へ渡すこと" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :guitar,
        overall_score: 70,
        pitch_score: 70,
        rhythm_score: 70,
        expression_score: 70,
        result_payload: {
          specific: {
            attack_score: 70,
            muting_score: 70,
            stability_score: 70
          }
        },
        created_at: 1.day.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :guitar,
        overall_score: 76,
        pitch_score: 74,
        rhythm_score: 70,
        expression_score: 80,
        result_payload: {
          specific: {
            attack_score: 76,
            muting_score: 68,
            stability_score: 70
          }
        },
        created_at: Time.current
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "ギター比較コメントです。"
      )

      described_class.call(diagnosis, client: client)

      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(input["specific_comparison"]).to contain_exactly(
          include("label" => "アタック", "delta" => "+6"),
          include("label" => "ミュート", "delta" => "-2"),
          include("label" => "安定感", "delta" => "±0")
        )
      end
    end

    it "bassでは専用promptとspecificスコアをコメント生成入力へ渡すこと" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        performance_type: :bass,
        overall_score: 76,
        pitch_score: 72,
        rhythm_score: 82,
        expression_score: 70,
        result_payload: {
          schema_version: 1,
          performance_type: "bass",
          common: {
            overall_score: 76,
            pitch_score: 72,
            rhythm_score: 82,
            expression_score: 70
          },
          specific: {
            groove_score: 78,
            note_length_score: 69,
            stability_score: 74
          }
        }
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "ベース向けコメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to eq "ベース向けコメントです。"
      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(args[:instructions]).to include("bassでは")
        expect(args[:instructions]).to include("グルーヴ、音価、リズム、安定感")
        expect(args[:instructions]).to include("ベース演奏として曲をどう支えているか")
        expect(args[:instructions]).to include("guitar固有")
        expect(args[:instructions]).to include("ピッキング")
        expect(input["performance_type"]).to eq "bass"
        expect(input["performance_type_label"]).to eq "ベース"
        expect(input["specific_scores"]).to include(include("label" => "グルーヴ"))
        expect(input["specific_scores"]).to include(include("label" => "音価"))
        expect(input["specific_scores"]).to include(include("label" => "安定感"))
        expect(input["advanced_feedback"].map { |feedback| feedback["label"] }).to include("グルーヴ", "音価", "安定感", "全体のまとまり")
        expect(input.dig("bass_context", "specific_scores")).to include(
          "groove_score" => 78,
          "note_length_score" => 69,
          "stability_score" => 74
        )
        expect(input.dig("bass_context", "focus_points")).to include("低音の支え")
        expect(input.dig("bass_context", "advanced_feedback_summary").map { |feedback| feedback["label"] }).to include("グルーヴ", "音価", "安定感", "全体のまとまり")
      end
    end

    it "bassではspecific比較をbass_contextにも渡すこと" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :bass,
        overall_score: 70,
        pitch_score: 70,
        rhythm_score: 70,
        expression_score: 70,
        result_payload: {
          specific: {
            groove_score: 70,
            note_length_score: 70,
            stability_score: 70
          }
        },
        created_at: 1.day.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :bass,
        overall_score: 76,
        pitch_score: 74,
        rhythm_score: 80,
        expression_score: 72,
        result_payload: {
          specific: {
            groove_score: 78,
            note_length_score: 68,
            stability_score: 70
          }
        },
        created_at: Time.current
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "ベース比較コメントです。"
      )

      described_class.call(diagnosis, client: client)

      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(input["specific_comparison"]).to contain_exactly(
          include("label" => "グルーヴ", "delta" => "+8"),
          include("label" => "音価", "delta" => "-2"),
          include("label" => "安定感", "delta" => "±0")
        )
        expect(input.dig("bass_context", "specific_comparison")).to contain_exactly(
          include("label" => "グルーヴ", "delta" => "+8"),
          include("label" => "音価", "delta" => "-2"),
          include("label" => "安定感", "delta" => "±0")
        )
      end
    end

    it "specificがないbassでも安全にbass_contextを作ること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        performance_type: :bass,
        result_payload: nil
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "ベース向けコメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to eq "ベース向けコメントです。"
      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(input.dig("result_payload", "specific")).to eq({})
        expect(input["specific_scores"]).to eq []
        expect(input["specific_comparison"]).to eq []
        expect(input.dig("bass_context", "specific_scores")).to eq({})
        expect(input.dig("bass_context", "specific_comparison")).to eq []
      end
    end

    it "drumsでは専用promptとspecificと詳細フィードバック要旨を入力に含めること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        performance_type: :drums,
        overall_score: 74,
        pitch_score: 65,
        rhythm_score: 80,
        expression_score: 72,
        result_payload: {
          schema_version: 1,
          performance_type: "drums",
          common: {
            overall_score: 74,
            pitch_score: 65,
            rhythm_score: 80,
            expression_score: 72
          },
          specific: {
            tempo_stability_score: 76,
            rhythm_precision_score: 71,
            dynamics_score: 68,
            fill_control_score: 73
          }
        }
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "ドラム向けコメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to eq "ドラム向けコメントです。"
      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(args[:instructions]).to include("drumsでは")
        expect(args[:instructions]).to include("テンポ安定、リズム精度、ダイナミクス、フィルコントロール")
        expect(args[:instructions]).to include("advanced_feedback_summary")
        expect(args[:instructions]).to include("バンド全体の土台")
        expect(args[:instructions]).to include("vocal固有")
        expect(args[:instructions]).to include("guitar固有")
        expect(args[:instructions]).to include("bass固有")
        expect(args[:instructions]).to include("ドラム演奏としてビート")
        expect(input["performance_type"]).to eq "drums"
        expect(input["performance_type_label"]).to eq "ドラム"
        expect(input["advanced_feedback"]).to include(include("label" => "テンポ安定"))
        expect(input["advanced_feedback"]).to include(include("label" => "リズム精度"))
        expect(input["advanced_feedback"]).to include(include("label" => "ダイナミクス"))
        expect(input["advanced_feedback"]).to include(include("label" => "フィルコントロール"))
        expect(input["specific_scores"]).to include(include("label" => "テンポ安定"))
        expect(input["specific_scores"]).to include(include("label" => "リズム精度"))
        expect(input["specific_scores"]).to include(include("label" => "ダイナミクス"))
        expect(input["specific_scores"]).to include(include("label" => "フィル"))
        expect(input.dig("drums_context", "specific_scores")).to include(
          "tempo_stability_score" => 76,
          "rhythm_precision_score" => 71,
          "dynamics_score" => 68,
          "fill_control_score" => 73
        )
        expect(input.dig("drums_context", "advanced_feedback_summary")).to include(
          include("label" => "テンポ安定"),
          include("label" => "リズム精度"),
          include("label" => "ダイナミクス"),
          include("label" => "フィルコントロール")
        )
      end
    end

    it "specificがないdrumsでも安全にdrums_contextを作ること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        performance_type: :drums,
        result_payload: nil
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "ドラム向けコメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to eq "ドラム向けコメントです。"
      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(input.dig("result_payload", "specific")).to eq({})
        expect(input["specific_scores"]).to eq []
        expect(input["specific_comparison"]).to eq []
        expect(input.dig("drums_context", "specific_scores")).to eq({})
        expect(input.dig("drums_context", "specific_comparison")).to eq []
        expect(input.dig("drums_context", "advanced_feedback_summary")).to include(
          include("label" => "テンポ安定"),
          include("label" => "全体のまとまり")
        )
      end
    end

    it "drumsのspecific前回比を入力に含めること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :drums,
        result_payload: {
          specific: {
            tempo_stability_score: 70,
            rhythm_precision_score: 72,
            dynamics_score: 65,
            fill_control_score: 73
          }
        },
        created_at: 1.day.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :drums,
        result_payload: {
          specific: {
            tempo_stability_score: 75,
            rhythm_precision_score: 70,
            dynamics_score: 65,
            fill_control_score: 78
          }
        },
        created_at: Time.current
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "ドラム比較コメントです。"
      )

      described_class.call(diagnosis, client: client)

      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(input["specific_comparison"]).to contain_exactly(
          include("label" => "テンポ安定", "delta" => "+5"),
          include("label" => "リズム精度", "delta" => "-2"),
          include("label" => "ダイナミクス", "delta" => "±0"),
          include("label" => "フィル", "delta" => "+5")
        )
        expect(input.dig("drums_context", "specific_comparison")).to contain_exactly(
          include("label" => "テンポ安定", "delta" => "+5"),
          include("label" => "リズム精度", "delta" => "-2"),
          include("label" => "ダイナミクス", "delta" => "±0"),
          include("label" => "フィル", "delta" => "+5")
        )
      end
    end

    it "keyboardでは専用promptとspecificと詳細フィードバック要旨を入力に含めること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        performance_type: :keyboard,
        overall_score: 78,
        pitch_score: 80,
        rhythm_score: 72,
        expression_score: 76,
        result_payload: {
          schema_version: 1,
          performance_type: "keyboard",
          common: {
            overall_score: 78,
            pitch_score: 80,
            rhythm_score: 72,
            expression_score: 76
          },
          specific: {
            chord_stability_score: 77,
            note_connection_score: 72,
            touch_score: 69,
            harmony_score: 74
          }
        }
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "キーボード向けコメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to eq "キーボード向けコメントです。"
      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(args[:instructions]).to include("keyboardでは")
        expect(args[:instructions]).to include("コード安定")
        expect(args[:instructions]).to include("音のつながり")
        expect(args[:instructions]).to include("コードチェンジ時の安定")
        expect(args[:instructions]).to include("打鍵の揃い方")
        expect(args[:instructions]).to include("specific_summary")
        expect(args[:instructions]).to include("vocal固有")
        expect(args[:instructions]).to include("guitar固有")
        expect(args[:instructions]).to include("bass固有")
        expect(args[:instructions]).to include("drums固有")
        expect(args[:instructions]).to include("和音のまとまり")
        expect(args[:instructions]).not_to include("ピッキング")
        expect(args[:instructions]).not_to include("ミュート")
        expect(args[:instructions]).not_to include("フィル")
        expect(args[:instructions]).not_to include("ストローク")
        expect(input["performance_type"]).to eq "keyboard"
        expect(input["performance_type_label"]).to eq "キーボード"
        expect(input["specific_scores"]).to include(include("label" => "コード安定"))
        expect(input["specific_scores"]).to include(include("label" => "音のつながり"))
        expect(input["specific_scores"]).to include(include("label" => "タッチ"))
        expect(input["specific_scores"]).to include(include("label" => "ハーモニー"))
        expect(input.dig("keyboard_context", "specific_scores")).to include(
          "chord_stability_score" => 77,
          "note_connection_score" => 72,
          "touch_score" => 69,
          "harmony_score" => 74
        )
        expect(input.dig("keyboard_context", "focus_points")).to include(
          "コードチェンジ時の安定感",
          "フレーズのつながり",
          "打鍵の粒立ち",
          "伴奏の支え方",
          "音の重なりの自然さ"
        )
        expect(input.dig("keyboard_context", "specific_summary", "strongest")).to include(
          "label" => "コード安定",
          "focus" => "コードチェンジ時の安定感"
        )
        expect(input.dig("keyboard_context", "specific_summary", "weakest")).to include(
          "label" => "タッチ",
          "priority" => "整えると伸びやすい"
        )
        expect(input.dig("keyboard_context", "practice_suggestions").map { |suggestion| suggestion["label"] }).to include("タッチ", "音のつながり")
        expect(input.dig("keyboard_context", "practice_suggestions").map { |suggestion| suggestion["suggestion"] }.join).to include("打鍵")
        expect(input.dig("keyboard_context", "advanced_feedback_summary")).to include(
          include("label" => "コード安定"),
          include("label" => "音のつながり"),
          include("label" => "タッチ"),
          include("label" => "ハーモニー"),
          include("label" => "全体のまとまり")
        )
      end
    end

    it "keyboardのspecific前回比を入力に含めること" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :keyboard,
        result_payload: {
          specific: {
            chord_stability_score: 70,
            note_connection_score: 72,
            touch_score: 68,
            harmony_score: 74
          }
        },
        created_at: 1.day.ago
      )
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        performance_type: :keyboard,
        result_payload: {
          specific: {
            chord_stability_score: 76,
            note_connection_score: 70,
            touch_score: 68,
            harmony_score: 79
          }
        },
        created_at: Time.current
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "キーボード比較コメントです。"
      )

      described_class.call(diagnosis, client: client)

      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(input["specific_comparison"]).to contain_exactly(
          include("label" => "コード安定", "delta" => "+6"),
          include("label" => "音のつながり", "delta" => "-2"),
          include("label" => "タッチ", "delta" => "±0"),
          include("label" => "ハーモニー", "delta" => "+5")
        )
        expect(input.dig("keyboard_context", "specific_comparison")).to contain_exactly(
          include("label" => "コード安定", "delta" => "+6", "state" => "up"),
          include("label" => "音のつながり", "delta" => "-2", "state" => "down"),
          include("label" => "タッチ", "delta" => "±0", "state" => "flat"),
          include("label" => "ハーモニー", "delta" => "+5", "state" => "up")
        )
        expect(input.dig("keyboard_context", "comparison_summary", "improved")).to include(
          include("label" => "コード安定", "delta" => "+6"),
          include("label" => "ハーモニー", "delta" => "+5")
        )
        expect(input.dig("keyboard_context", "comparison_summary", "declined")).to include(
          include("label" => "音のつながり", "delta" => "-2")
        )
      end
    end

    it "specificがないkeyboardでも安全にkeyboard_contextを作ること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        performance_type: :keyboard,
        result_payload: nil
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "キーボード向けコメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to eq "キーボード向けコメントです。"
      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(args[:instructions]).to include("keyboardでは")
        expect(input["performance_type"]).to eq "keyboard"
        expect(input.dig("result_payload", "specific")).to eq({})
        expect(input["specific_scores"]).to eq []
        expect(input["specific_comparison"]).to eq []
        expect(input.dig("keyboard_context", "specific_scores")).to eq({})
        expect(input.dig("keyboard_context", "specific_summary")).to eq({})
        expect(input.dig("keyboard_context", "specific_comparison")).to eq []
        expect(input.dig("keyboard_context", "comparison_summary")).to eq({})
        expect(input.dig("keyboard_context", "practice_suggestions").map { |suggestion| suggestion["label"] }).to eq ["コード安定", "音のつながり"]
      end
    end

    it "bandではアンサンブル診断向けの文脈を入力に含めること" do
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        status: :completed,
        performance_type: :band,
        overall_score: 79,
        pitch_score: 74,
        rhythm_score: 71,
        expression_score: 76,
        result_payload: {
          schema_version: 1,
          performance_type: "band",
          common: {
            overall_score: 79,
            pitch_score: 74,
            rhythm_score: 71,
            expression_score: 76
          },
          specific: {
            balance: 78,
            tightness: 72,
            groove: 75,
            role_clarity: 68,
            dynamics: 80,
            cohesion: 73
          },
          quality_flags: {
            low_confidence: true
          }
        }
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "バンド向けコメントです。"
      )

      comment = described_class.call(diagnosis, client: client)

      expect(comment).to eq "バンド向けコメントです。"
      expect(client).to have_received(:generate_text) do |args|
        input = JSON.parse(args[:input])

        expect(args[:instructions]).to include("bandでは")
        expect(args[:instructions]).to include("アンサンブル")
        expect(args[:instructions]).to include("音量バランス")
        expect(args[:instructions]).to include("一体感")
        expect(args[:instructions]).to include("主旋律")
        expect(args[:instructions]).to include("リズム隊")
        expect(input["performance_type"]).to eq "band"
        expect(input["performance_type_label"]).to eq "バンド演奏"
        expect(input["specific_scores"]).to include(include("label" => "音量バランス", "description" => include("聴きやすい状態")))
        expect(input["specific_scores"]).to include(include("label" => "一体感"))
        expect(input.dig("band_context", "focus_points")).to include("音量バランス", "グルーヴのまとまり")
        expect(input.dig("band_context", "score_cards")).to include(include("label" => "音量バランス"))
        expect(input.dig("band_context", "strengths").map { |item| item["label"] }).to include("音量バランス", "抑揚・展開")
        expect(input.dig("band_context", "practice_points").join).to include("ドラムとベースだけで1コーラス合わせる", "誰の音が前に出すぎているか")
        expect(input.dig("weekly_coach_context", "theme")).to include("各パート")
        expect(input.dig("weekly_coach_context", "goal")).to include("主役と支え役")
        expect(input.dig("weekly_coach_context", "studio_steps").join).to include("主役のパート", "録音")
        expect(input.dig("weekly_coach_context", "recording_points").join).to include("主旋律", "サビ")
        expect(input.dig("weekly_coach_context", "homework")).to include("前に出る場所")
        expect(input.dig("weekly_coach_context", "quality_note")).to include("参考値")
      end
    end

    it "premium診断では詳細な診断項目と歌声タイプをOpenAI clientへ渡すこと" do
      customer = FactoryBot.create(:customer, domain_name: "singing")
      customer.create_subscription!(status: "active", plan: "premium")
      diagnosis = FactoryBot.create(
        :singing_diagnosis,
        customer: customer,
        status: :completed,
        overall_score: 84,
        pitch_score: 88,
        rhythm_score: 76,
        expression_score: 82
      )
      client = instance_double(
        SingingDiagnoses::OpenAiResponsesClient,
        generate_text: "Premium診断コメントです。"
      )

      described_class.call(diagnosis, client: client)

      expect(client).to have_received(:generate_text) do |args|
        expect(args[:input]).to include("premium_diagnosis")
        expect(args[:input]).to include("voice_check_items")
        expect(args[:input]).to include("mix_voice_check_items")
        expect(args[:input]).to include("voice_type")
        expect(args[:max_output_tokens]).to eq 900
      end
    end

    it "completed以外は生成しないこと" do
      diagnosis = FactoryBot.create(:singing_diagnosis, status: :processing)
      client = instance_double(SingingDiagnoses::OpenAiResponsesClient)

      expect { described_class.call(diagnosis, client: client) }.to raise_error(ArgumentError)
    end
  end
end
