module SingingDiagnoses
  class AiCommentGenerator
    MAX_COMMENT_LENGTH = 2000
    PERFORMANCE_TYPE_INSTRUCTIONS = {
      "vocal" => [
        "vocalでは、歌唱指導寄りに、音程・リズム・表現・声量・発音・リラックス・ミックスボイスを必要に応じて扱ってください。",
        "歌声タイプがある場合は、本人の魅力を固定せず、取り入れると良い方向性として表現してください。"
      ],
      "guitar" => [
        "guitarでは、ギター演奏のコーチとして、アタック、ミュート、安定感、フレーズの輪郭、演奏のまとまりを中心にコメントしてください。",
        "attack_scoreは音の立ち上がりやピッキングの粒、muting_scoreは不要な残響や鳴らしたくない弦の整理、stability_scoreは音量・タイミング・演奏全体の安定感として扱ってください。",
        "specific_comparisonがある場合は、同じ補足スコアの前回比を成長や振り返りの目安として自然に触れてください。",
        "vocal固有の歌声、喉、ミックスボイス、発音、声量といった表現は使わないでください。",
        "データが不足する場合は、録音から見える範囲の練習ヒントとして控えめに表現してください。"
      ],
      "bass" => [
        "bassでは、ベース演奏のコーチとして、グルーヴ、音価、リズム、安定感、低音の支え、バンド全体を前に進める流れを中心にコメントしてください。",
        "groove_scoreはリズムのまとまりやノリ、note_length_scoreは音の長さや切れ際、stability_scoreは音量・タイミング・低音の支えの安定感として扱ってください。",
        "specific_comparisonがある場合は、同じ補足スコアの前回比を成長や振り返りの目安として自然に触れてください。",
        "vocal固有の歌声、喉、ミックスボイス、発音、声量といった表現は使わないでください。",
        "guitar固有のピッキング、アタックの輪郭、不要弦ミュートといった表現をそのまま流用しないでください。",
        "演奏が土台としてどう機能しているか、リズムの気持ちよさや音価のそろい方がどう聴こえるかをイメージしやすく表現してください。",
        "データが不足する場合は、曲全体を支える演奏の目安として控えめに表現してください。"
      ],
      "drums" => [
        "drumsでは、ドラム演奏のコーチとして、テンポ安定、リズム精度、ダイナミクス、フィルコントロール、ビートの土台、演奏全体を前に進める推進力を中心にコメントしてください。",
        "tempo_stability_scoreはテンポの保ちやすさ、rhythm_precision_scoreは叩きのタイミングや粒の揃い方、dynamics_scoreは強弱の自然さ、fill_control_scoreはフィル後の着地や展開のまとまりとして扱ってください。",
        "advanced_feedback_summaryがある場合は、テンポ・リズム・強弱・フィル・全体のまとまりの読み解きから、ユーザーが次に試せる練習ポイントを1つか2つに絞ってください。",
        "specific_comparisonがある場合は、同じ補足スコアの前回比を成長や振り返りの目安として自然に触れてください。",
        "vocal固有の歌声、喉、ミックスボイス、発音、声量といった表現は使わないでください。",
        "guitar固有のピッキング、アタックの輪郭、不要弦ミュートといった表現を使わないでください。",
        "bass固有の低音の支え、音価の揃い、ベースラインといった表現を使わないでください。",
        "録音から見える範囲の目安として、ビートがどう聴こえるか、バンド全体の土台としてどう機能しているか、次に何を整えると演奏がまとまりやすいかを控えめに表現してください。"
      ],
      "keyboard" => [
        "keyboardでは、キーボード演奏のコーチとして、コード安定、音のつながり、タッチ、ハーモニー、リズム、伴奏としての支え方、演奏全体の流れを中心にコメントしてください。",
        "chord_stability_scoreは和音の押さえやコードチェンジ時の安定、note_connection_scoreはフレーズの滑らかさや次の音への移行、touch_scoreは強弱コントロールや打鍵の揃い方、harmony_scoreは和声のまとまりや音の重なりの自然さとして扱ってください。",
        "keyboard_contextのspecific_summary、comparison_summary、practice_suggestions、advanced_feedback_summaryがある場合は、強み・改善優先度・前回比・次の一歩を1つか2つに絞って自然に反映してください。",
        "specific_comparisonがある場合は、同じ補足スコアの前回比を成長や振り返りの目安として自然に触れてください。",
        "vocal固有の歌声、喉、ミックスボイス、発音、声量といった表現は使わないでください。",
        "guitar固有、bass固有、drums固有の奏法語彙をそのまま流用しないでください。",
        "データが不足する場合は、録音から見える範囲で、和音のまとまり、音のつながり、打鍵の丁寧さを整えるためのヒントとして控えめに表現してください。"
      ],
      "band" => [
        "bandでは、バンド全体のアンサンブルコーチとして、アンサンブル力、調和、役割理解、音量バランス、リズムの揃い、グルーヴ、ダイナミクス、全体のまとまりを中心にコメントしてください。",
        "pitch_scoreは調和やハーモニーの自然さ、rhythm_scoreはリズムの揃い、expression_scoreはダイナミクスや展開の付け方として扱ってください。",
        "ensemble_scoreはアンサンブル力、role_understanding_scoreは役割理解、volume_balance_scoreは音量バランス、rhythm_unity_scoreはリズムの揃い、groove_scoreはノリのまとまり、dynamics_scoreは強弱の設計、cohesion_scoreはバンド全体のまとまりとして扱ってください。",
        "ボーカルや主旋律の聴こえ方、リズム隊の安定感、各パートの出すぎ・引きすぎ、曲の展開に合わせたダイナミクス、バンド全体の一体感を必ずどこかで触れてください。",
        "次回の練習で意識すべきポイントは1〜3個に絞り、スタジオやセッションですぐ試せる形で提案してください。",
        "個人技の優劣を断定するのではなく、各パートがどう噛み合うとより良く聴こえるかをイメージしやすく伝えてください。",
        "vocalや各楽器固有の奏法語彙に寄りすぎず、バンド全体の聴こえ方として自然な日本語にしてください。",
        "データが不足する場合は、録音から見える範囲のアンサンブル改善ヒントとして控えめに表現してください。"
      ]
    }.freeze

    KEYBOARD_SPECIFIC_SCORE_DETAILS = {
      chord_stability_score: {
        label: "コード安定",
        focus: "コードチェンジ時の安定感",
        practice: "コードチェンジを2つに絞り、切り替え直後の響きが揺れすぎないかをゆっくり確認する"
      },
      note_connection_score: {
        label: "音のつながり",
        focus: "フレーズの滑らかさ",
        practice: "短いフレーズで前の音が消えるタイミングと次の音の入りをそろえる"
      },
      touch_score: {
        label: "タッチ",
        focus: "打鍵の粒立ちと強弱",
        practice: "同じフレーズを弱め・普通・少し強めで弾き分け、打鍵の強さが急に跳ねないか録音で確認する"
      },
      harmony_score: {
        label: "ハーモニー",
        focus: "音の重なりの自然さ",
        practice: "気になるコードを長めに鳴らし、強すぎる音や埋もれる音がないかを聴き分ける"
      }
    }.freeze

    def self.call(diagnosis, client: nil)
      new(diagnosis, client: client).call
    end

    def initialize(diagnosis, client: nil)
      @diagnosis = diagnosis
      @client = client || OpenAiResponsesClient.new
      @helper = Class.new { include Singing::DiagnosesHelper }.new
    end

    def call
      raise ArgumentError, "diagnosis must be completed" unless diagnosis.completed?

      client.generate_text(
        instructions: instructions,
        input: prompt,
        max_output_tokens: max_output_tokens
      ).to_s.strip.truncate(MAX_COMMENT_LENGTH)
    end

    private

    attr_reader :diagnosis, :client, :helper

    def instructions
      [
        "あなたは歌唱・演奏の練習を支援するコーチです。",
        "診断スコア、詳細フィードバック、前回比較、診断タイプ別の補足スコアをもとに、日本語で短いコメントを作成してください。",
        "点数の上下を断定的な優劣として煽らず、成長支援のトーンを維持してください。",
        "医療的・専門的な断定は避け、練習のヒントとして表現してください。",
        "Premium診断では、利用可能な詳細診断項目も踏まえてください。",
        "reference_comparisonがある場合は、曲のキーやテンポにどれくらい近いかを、断定しすぎず練習の目安として自然に触れてください。",
        "weekly_coach_contextがある場合は、今週の練習テーマや曲基準メモも踏まえて、次の一歩が一貫して見えるようにまとめてください。",
        performance_type_instruction,
        output_instruction
      ].flatten.join("\n")
    end

    def prompt
      data = {
        performance_type: diagnosis.performance_type,
        performance_type_label: diagnosis.performance_type_label,
        song_title: diagnosis.song_title.presence || "未入力",
        memo: diagnosis.memo.to_s.truncate(300),
        scores: {
          overall: diagnosis.overall_score,
          pitch: diagnosis.pitch_score,
          rhythm: diagnosis.rhythm_score,
          expression: diagnosis.expression_score
        },
        result_payload: {
          schema_version: result_payload_value(:schema_version),
          performance_type: result_payload_value(:performance_type),
          common: result_payload_value(:common) || {},
          specific: specific_scores
        },
        advanced_feedback: feedback_cards.map do |card|
          {
            label: card[:label],
            score: card[:score],
            summary: card[:summary],
            strength: card[:strength],
            next_step: card[:next_step]
          }
        end,
        comparison: comparison_rows.map do |row|
          {
            label: row[:label],
            previous: row[:previous],
            current: row[:current],
            delta: row[:delta_label],
            message: row[:message]
          }
        end,
        specific_scores: specific_score_cards.map do |card|
          {
            key: card[:key],
            label: card[:label],
            score: card[:score],
            comment: card[:comment],
            description: card[:description],
            rating: card[:rating]
          }
        end,
        specific_comparison: specific_comparison_rows.map do |row|
          {
            key: row[:key],
            label: row[:label],
            previous: row[:previous],
            current: row[:current],
            delta: row[:delta_label],
            message: row[:message]
          }
        end,
        weekly_coach_context: weekly_coach_context,
        reference_comparison: reference_comparison,
        reference_context: reference_context
      }
      data[:guitar_context] = guitar_context if diagnosis.performance_type_guitar?
      data[:bass_context] = bass_context if diagnosis.performance_type_bass?
      data[:drums_context] = drums_context if diagnosis.performance_type_drums?
      data[:keyboard_context] = keyboard_context if diagnosis.performance_type_keyboard?
      data[:band_context] = band_context if diagnosis.performance_type_band?

      if diagnosis.priority_analysis?
        data[:premium_diagnosis] = {
          voice_check_items: helper.singing_premium_voice_check_items(diagnosis),
          mix_voice_check_items: helper.singing_premium_mix_voice_check_items(diagnosis),
          voice_type: helper.singing_premium_voice_type(diagnosis)
        }
      end

      data.to_json
    end

    def max_output_tokens
      diagnosis.priority_analysis? ? 900 : 500
    end

    def performance_type_instruction
      PERFORMANCE_TYPE_INSTRUCTIONS[diagnosis.performance_type.to_s] || PERFORMANCE_TYPE_INSTRUCTIONS["vocal"]
    end

    def output_instruction
      if diagnosis.performance_type_vocal?
        "出力は見出し付きで、総評、ワンポイントアドバイス、歌声タイプの3項目を中心に900文字以内にしてください。"
      elsif diagnosis.performance_type_guitar?
        "出力は見出し付きで、総評、ワンポイントアドバイス、次に意識する練習の3項目を中心に900文字以内にしてください。ギター演奏としてどう聴こえるかがイメージできる自然な日本語にしてください。"
      elsif diagnosis.performance_type_bass?
        "出力は見出し付きで、総評、ワンポイントアドバイス、次に意識する練習の3項目を中心に900文字以内にしてください。ベース演奏として曲をどう支えているかがイメージできる自然な日本語にしてください。"
      elsif diagnosis.performance_type_drums?
        "出力は見出し付きで、総評、ワンポイントアドバイス、次に意識する練習の3項目を中心に900文字以内にしてください。ドラム演奏としてビートがどう聴こえるか、バンド全体を前に進める土台としてどう機能しているか、テンポ・叩きの粒・強弱・フィルをどう整えるとまとまりやすいかがイメージできる自然な日本語にしてください。"
      elsif diagnosis.performance_type_keyboard?
        "出力は見出し付きで、総評、ワンポイントアドバイス、次に意識する練習の3項目を中心に900文字以内にしてください。キーボード演奏として和音のまとまりや音のつながり、タッチの安定がどう聴こえるかがイメージできる自然な日本語にしてください。"
      elsif diagnosis.performance_type_band?
        "出力は見出し付きで、総評、ワンポイントアドバイス、次に意識する練習の3項目を中心に900文字以内にしてください。バンド全体として、各パートの噛み合い方、音量バランス、リズムの揃い、グルーヴ、ダイナミクスがどう聴こえるかをイメージできる自然な日本語にしてください。"
      else
        "出力は見出し付きで、総評、ワンポイントアドバイス、次に意識する練習の3項目を中心に900文字以内にしてください。"
      end
    end

    def band_context
      cards = specific_score_cards

      {
        focus_points: [
          "アンサンブルの噛み合い方",
          "役割の住み分け",
          "音量バランス",
          "リズムの揃い",
          "グルーヴのまとまり",
          "ダイナミクスの設計",
          "バンド全体のまとまり"
        ],
        specific_scores: cards.each_with_object({}) do |card, scores|
          scores[card[:key].to_s] = card[:score]
        end,
        score_cards: cards.map do |card|
          {
            key: card[:key],
            label: card[:label],
            score: card[:score],
            description: card[:description],
            rating: card[:rating],
            comment: card[:comment]
          }
        end,
        strengths: cards.select { |card| card[:score].to_i >= 70 }.sort_by { |card| -card[:score].to_i }.first(3).map do |card|
          {
            label: card[:label],
            score: card[:score],
            reason: card[:comment]
          }
        end,
        improvement_priorities: cards.select { |card| card[:score].present? }.sort_by { |card| card[:score].to_i }.first(3).map do |card|
          {
            label: card[:label],
            score: card[:score],
            reason: card[:comment]
          }
        end,
        specific_comparison: specific_comparison_rows.map do |row|
          {
            key: row[:key],
            label: row[:label],
            delta: row[:delta_label],
            message: row[:message]
          }
        end,
        advanced_feedback_summary: feedback_cards.map do |card|
          {
            label: card[:label],
            score: card[:score],
            summary: card[:summary],
            next_step: card[:next_step]
          }
        end,
        practice_points: [
          "ドラムとベースだけで1コーラス合わせる",
          "ボーカルや主旋律が自然に聴こえる音量まで全体を下げる",
          "Aメロ・Bメロ・サビで音量差をつける",
          "サビ前のキメやブレイクを全員で確認する",
          "録音して、誰の音が前に出すぎているかを確認する"
        ]
      }
    end

    def guitar_context
      {
        focus_points: [
          "音の立ち上がり",
          "不要な残響のコントロール",
          "フレーズの輪郭",
          "音量とタイミングの安定感",
          "演奏全体のまとまり"
        ],
        specific_scores: {
          attack_score: specific_scores[:attack_score],
          muting_score: specific_scores[:muting_score],
          stability_score: specific_scores[:stability_score]
        }.compact,
        advanced_feedback_summary: feedback_cards.map do |card|
          {
            label: card[:label],
            score: card[:score],
            summary: card[:summary],
            next_step: card[:next_step]
          }
        end
      }
    end

    def bass_context
      {
        focus_points: [
          "グルーヴのまとまり",
          "音価と切れ際",
          "低音の支え",
          "音量とタイミングの安定感",
          "曲全体を前に進める演奏の流れ"
        ],
        specific_scores: {
          groove_score: specific_scores[:groove_score],
          note_length_score: specific_scores[:note_length_score],
          stability_score: specific_scores[:stability_score]
        }.compact,
        specific_comparison: specific_comparison_rows.map do |row|
          {
            key: row[:key],
            label: row[:label],
            delta: row[:delta_label],
            message: row[:message]
          }
        end,
        advanced_feedback_summary: feedback_cards.map do |card|
          {
            label: card[:label],
            score: card[:score],
            summary: card[:summary],
            next_step: card[:next_step]
          }
        end
      }
    end

    def drums_context
      {
        focus_points: [
          "テンポの安定",
          "叩きのタイミングと粒の揃い方",
          "強弱の自然さ",
          "フィル後の着地",
          "ビート全体のまとまり",
          "演奏全体を前に進める推進力"
        ],
        specific_scores: {
          tempo_stability_score: specific_scores[:tempo_stability_score],
          rhythm_precision_score: specific_scores[:rhythm_precision_score],
          dynamics_score: specific_scores[:dynamics_score],
          fill_control_score: specific_scores[:fill_control_score]
        }.compact,
        specific_comparison: specific_comparison_rows.map do |row|
          {
            key: row[:key],
            label: row[:label],
            delta: row[:delta_label],
            message: row[:message]
          }
        end,
        advanced_feedback_summary: feedback_cards.map do |card|
          {
            label: card[:label],
            score: card[:score],
            summary: card[:summary],
            next_step: card[:next_step]
          }
        end
      }
    end

    def keyboard_context
      details = keyboard_specific_score_details

      {
        focus_points: [
          "コードチェンジ時の安定感",
          "フレーズのつながり",
          "打鍵の粒立ち",
          "伴奏の支え方",
          "音の重なりの自然さ",
          "演奏全体の流れ"
        ],
        specific_scores: {
          chord_stability_score: specific_scores[:chord_stability_score],
          note_connection_score: specific_scores[:note_connection_score],
          touch_score: specific_scores[:touch_score],
          harmony_score: specific_scores[:harmony_score]
        }.compact,
        specific_summary: keyboard_specific_summary(details),
        specific_comparison: specific_comparison_rows.map do |row|
          {
            key: row[:key],
            label: row[:label],
            previous: row[:previous],
            current: row[:current],
            delta: row[:delta_label],
            state: row[:state],
            message: row[:message]
          }
        end,
        comparison_summary: keyboard_comparison_summary,
        practice_suggestions: keyboard_practice_suggestions(details),
        advanced_feedback_summary: feedback_cards.map do |card|
          {
            label: card[:label],
            score: card[:score],
            summary: card[:summary],
            next_step: card[:next_step]
          }
        end
      }
    end

    def keyboard_specific_score_details
      KEYBOARD_SPECIFIC_SCORE_DETAILS.each_with_object([]) do |(key, config), details|
        score = specific_scores[key]
        next if score.blank?

        details << {
          key: key,
          label: config[:label],
          score: score.to_i,
          focus: config[:focus],
          practice: config[:practice],
          priority: keyboard_score_priority(score)
        }
      end
    end

    def keyboard_specific_summary(details)
      return {} if details.blank?

      strongest = details.max_by { |detail| detail[:score] }
      weakest = details.min_by { |detail| detail[:score] }

      {
        strongest: keyboard_summary_item(strongest, "強みとして活かしやすい項目です"),
        weakest: keyboard_summary_item(weakest, "次の練習課題として優先しやすい項目です"),
        improvement_priority: weakest[:label],
        overall_direction: keyboard_overall_direction(details)
      }
    end

    def keyboard_summary_item(detail, note)
      {
        key: detail[:key],
        label: detail[:label],
        score: detail[:score],
        focus: detail[:focus],
        note: note,
        priority: detail[:priority]
      }
    end

    def keyboard_comparison_summary
      rows = specific_comparison_rows
      return {} if rows.blank?

      {
        improved: rows.select { |row| row[:delta].to_i.positive? }.map { |row| keyboard_comparison_item(row) },
        declined: rows.select { |row| row[:delta].to_i.negative? }.map { |row| keyboard_comparison_item(row) },
        flat: rows.select { |row| row[:delta].to_i.zero? }.map { |row| keyboard_comparison_item(row) }
      }
    end

    def keyboard_comparison_item(row)
      {
        key: row[:key],
        label: row[:label],
        delta: row[:delta_label],
        message: row[:message]
      }
    end

    def keyboard_practice_suggestions(details)
      source = if details.present?
                 details.sort_by { |detail| detail[:score] }.first(2)
               else
                 KEYBOARD_SPECIFIC_SCORE_DETAILS.first(2).map do |key, config|
                   {
                     key: key,
                     label: config[:label],
                     focus: config[:focus],
                     practice: config[:practice],
                     priority: "データ不足時の確認ポイント"
                   }
                 end
               end

      source.map do |detail|
        {
          label: detail[:label],
          focus: detail[:focus],
          suggestion: detail[:practice],
          priority: detail[:priority]
        }
      end
    end

    def keyboard_score_priority(score)
      value = score.to_i

      if value >= 80
        "強みとして維持"
      elsif value >= 60
        "整えると伸びやすい"
      else
        "基礎優先"
      end
    end

    def keyboard_overall_direction(details)
      weakest = details.min_by { |detail| detail[:score] }
      return "和音のまとまり、音のつながり、打鍵の丁寧さを録音で確認しながら整えると、演奏全体の安定につながります。" if weakest.blank?

      case weakest[:key]
      when :chord_stability_score
        "まずはコードチェンジ時の安定感を整えると、伴奏全体の安心感を作りやすくなります。"
      when :note_connection_score
        "音の移行をなめらかにすると、フレーズの流れが自然に聴こえやすくなります。"
      when :touch_score
        "打鍵の強さと粒をそろえると、丁寧さと表現の両方が伝わりやすくなります。"
      when :harmony_score
        "音の重なりの自然さを整えると、ハーモニーの安定感と演奏全体の彩りが出やすくなります。"
      else
        "和音のまとまり、音のつながり、打鍵の丁寧さを録音で確認しながら整えると、演奏全体の安定につながります。"
      end
    end

    def reference_context
      comparison = reference_comparison
      return {} if comparison.blank?

      {
        summary: reference_comparison_summary(comparison),
        key_guidance: reference_key_guidance(comparison),
        tempo_guidance: reference_tempo_guidance(comparison)
      }.compact
    end

    def weekly_coach_context
      coach = helper.singing_weekly_coach_card(diagnosis)
      return {} if coach.blank?

      {
        theme: coach[:theme],
        focus: coach[:focus],
        practice_title: coach[:practice_title],
        practice_description: coach[:practice_description],
        encouragement: coach[:encouragement],
        reference_note: coach[:reference_note],
        quality_note: coach[:quality_note],
        goal: coach[:goal],
        studio_steps: coach[:studio_steps],
        recording_points: coach[:recording_points],
        homework: coach[:homework]
      }.compact
    rescue StandardError
      {}
    end

    def reference_comparison
      @reference_comparison ||= begin
        if diagnosis.respond_to?(:reference_comparison)
          diagnosis.reference_comparison || {}
        else
          result_payload_value(:reference_comparison) || {}
        end
      end
    end

    def reference_comparison_summary(comparison)
      parts = []
      if comparison_value(comparison, :reference_key).present?
        parts << "参考キー#{comparison_value(comparison, :reference_key)}に対して、推定キーは#{comparison_value(comparison, :estimated_key).presence || '推定不可'}です。"
      end
      if comparison_value(comparison, :reference_bpm).present?
        parts << "参考テンポ#{comparison_value(comparison, :reference_bpm)}BPMに対して、推定テンポは#{comparison_value(comparison, :estimated_bpm).presence || '推定不可'}BPMです。"
      end
      parts.join(" ")
    end

    def reference_key_guidance(comparison)
      case comparison_value(comparison, :key_match_level)
      when "exact"
        "キーは参考情報とかなり近く、曲の中心に乗れている目安として扱えます。"
      when "close"
        "キーは大きく外れてはいない可能性があります。細かな音程やコードの着地を確認すると、さらに曲に寄せやすくなります。"
      when "far"
        "キーは参考情報から離れている可能性があります。原曲キー、移調、録音音源の高さを確認すると振り返りやすくなります。"
      when "unknown"
        "キーは録音から安定して推定できませんでした。参考程度に留め、耳での確認も合わせて使ってください。"
      end
    end

    def reference_tempo_guidance(comparison)
      case comparison_value(comparison, :tempo_match_level)
      when "close"
        "テンポは参考BPMに近く、曲の流れに乗れている目安として扱えます。"
      when "near"
        "テンポは少し差があります。メトロノームや原曲に合わせて、入りと終わりのテンポ感を確認すると整いやすくなります。"
      when "far"
        "テンポ差が大きめです。まずはゆっくり合わせてから、原曲テンポへ近づける練習が有効です。"
      when "unknown"
        "テンポは録音から安定して推定できませんでした。参考程度に留め、原曲やクリックとの比較も使ってください。"
      end
    end

    def comparison_value(comparison, key)
      comparison[key] || comparison[key.to_s]
    end

    def result_payload_value(key)
      payload = diagnosis.result_payload
      return unless payload.respond_to?(:[])

      payload[key] || payload[key.to_s]
    end

    def specific_scores
      @specific_scores ||= helper.singing_specific_scores(diagnosis)
    end

    def specific_score_cards
      @specific_score_cards ||= helper.singing_specific_score_cards(diagnosis)
    end

    def specific_comparison_rows
      @specific_comparison_rows ||= helper.singing_specific_score_comparison_rows(diagnosis)
    end

    def feedback_cards
      @feedback_cards ||= if helper.singing_advanced_feedback_available?(diagnosis)
                            helper.singing_advanced_feedback_cards(diagnosis)
                          else
                            []
                          end
    end

    def comparison_rows
      @comparison_rows ||= helper.singing_score_comparison_rows(diagnosis)
    end
  end
end
