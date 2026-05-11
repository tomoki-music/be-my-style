module SingingDiagnoses
  # 6つの歌声タイプに対してスコアを算出し、main/sub/hidden_potential を返すサービス。
  #
  # 偏りを防ぐ設計方針:
  # - 各タイプに固有の "key indicator" を設け、単一特徴量だけでは決定しない
  # - wild は expression × tension (=1-relax) の積で閾値を設けることで、
  #   expression が高いだけではワイルド判定されないようにする
  # - specific payload の vocal スコア (volume_score, relax_score, mix_voice_score,
  #   pronunciation_score) が存在する場合は優先使用し、ない場合は派生値で代替する
  class VoiceTypeAnalyzer
    VOICE_TYPE_LABELS = {
      powerful:  "パワフルボイス",
      high_tone: "ハイトーンボイス",
      crystal:   "クリスタルボイス",
      wild:      "ワイルドボイス",
      artistic:  "アーティスティックボイス",
      charisma:  "カリスマ（独特な世界観）"
    }.freeze

    VOICE_TYPE_DESCRIPTIONS = {
      powerful:  "声量と芯の強さが魅力のタイプです。まっすぐ前に届く歌声で、サビやロングトーンで存在感を発揮します。",
      high_tone: "高音域に魅力があるタイプです。伸びやかで響きのある高音が、聴く人の心にダイレクトに届きます。",
      crystal:   "透明感とやわらかさが魅力のタイプです。優しく澄んだ声で、聴く人の心を落ち着かせる力があります。",
      wild:      "声にエッジと熱量があるタイプです。フレーズに説得力があり、ロックや感情表現の強い楽曲で魅力を発揮します。",
      artistic:  "声に個性と余韻があるタイプです。一度聴くと印象に残りやすく、その人らしさが武器になります。",
      charisma:  "独特の世界観で惹き込むタイプです。単純な上手さだけでは測れない表現力があり、聴き手の記憶に残る歌声です。"
    }.freeze

    VOICE_TYPE_ADVICE = {
      powerful:  "ダイナミクスの幅を意識し、サビ以外でも強弱をつけるとさらに表現の奥行きが出ます。",
      high_tone: "高音時の息のコントロールを丁寧に練習すると、より長くクリアに伸ばせるようになります。",
      crystal:   "声の出だしを丁寧に揃えると、透明感がさらに際立ちます。録音して聴き返す習慣をつけましょう。",
      wild:      "力みがくる前に一呼吸おくポイントを作ると、エッジを活かしたまま安定感が増します。",
      artistic:  "フレーズの語尾や言葉の置き方を意識すると、個性がより強く伝わるようになります。",
      charisma:  "歌詞の解釈を深め、「間」の使い方にこだわると世界観がさらに際立ちます。"
    }.freeze

    VOICE_TYPE_SONG_TENDENCY = {
      powerful:  "パワーバラード・応援ソング・アニソンのサビ",
      high_tone: "J-POP・アニソン・ポップロックの高音フレーズ",
      crystal:   "バラード・アコースティック・癒し系ポップス",
      wild:      "ロック・ハードロック・感情表現の強い楽曲",
      artistic:  "フォーク・インディーポップ・個性派J-POP",
      charisma:  "独自世界観の強いアーティスト楽曲・シアトリカルポップ"
    }.freeze

    def self.call(diagnosis)
      new(diagnosis).call
    end

    def initialize(diagnosis)
      @diagnosis = diagnosis
    end

    def call
      scores    = compute_scores
      sorted    = scores.sort_by { |_, s| -s }
      main_type = sorted[0][0]
      sub_type  = sorted[1][0]

      hidden_potential = sorted[2..]
        .find { |type, score| score.between?(30, 60) }
        &.first

      {
        main_type:        main_type,
        sub_type:         sub_type,
        scores:           scores,
        hidden_potential: hidden_potential,
        labels:           VOICE_TYPE_LABELS,
        descriptions:     VOICE_TYPE_DESCRIPTIONS,
        advice:           VOICE_TYPE_ADVICE,
        song_tendency:    VOICE_TYPE_SONG_TENDENCY,
        reasoning:        build_reasoning(scores, main_type, sub_type)
      }
    end

    private

    attr_reader :diagnosis

    # ─────────────────────────────────────────────────
    # 基本スコア (DB カラム)
    # ─────────────────────────────────────────────────
    def overall;    @overall    ||= diagnosis.overall_score.to_i end
    def pitch;      @pitch      ||= diagnosis.pitch_score.to_i    end
    def rhythm;     @rhythm     ||= diagnosis.rhythm_score.to_i   end
    def expression; @expression ||= diagnosis.expression_score.to_i end

    # ─────────────────────────────────────────────────
    # Specific payload スコア（vocal 限定・存在時優先）
    # ─────────────────────────────────────────────────
    def specific
      @specific ||= begin
        payload = diagnosis.result_payload
        return {} unless payload.respond_to?(:[])

        specific_raw = payload[:specific] || payload["specific"]
        return {} unless specific_raw.respond_to?(:each_with_object)

        specific_raw.each_with_object({}) do |(k, v), h|
          num = v.to_i
          h[k.to_sym] = num if num.positive?
        end
      end
    end

    def eff_volume
      specific[:volume_score] || ((overall + expression) / 2.0)
    end

    def eff_relax
      specific[:relax_score] || ((pitch + rhythm) / 2.0)
    end

    def eff_mix_voice
      specific[:mix_voice_score] || pitch
    end

    def eff_pronunciation
      specific[:pronunciation_score] || ((pitch + rhythm + expression) / 3.0)
    end

    # 声帯緊張度: relax の逆数 (high = 張りが強い = ワイルド寄り)
    def tension
      (100 - eff_relax).clamp(0, 100)
    end

    # ─────────────────────────────────────────────────
    # スコア計算
    # ─────────────────────────────────────────────────
    def compute_scores
      {
        powerful:  score_powerful,
        high_tone: score_high_tone,
        crystal:   score_crystal,
        wild:      score_wild,
        artistic:  score_artistic,
        charisma:  score_charisma
      }.transform_values { |s| s.round.clamp(0, 100) }
    end

    # パワフルボイス: 声量 + 表現 + 全体
    # 重視: volume_score (key indicator), expression, overall, rhythm(安定)
    def score_powerful
      (eff_volume * 0.40 +
       expression * 0.25 +
       overall    * 0.25 +
       rhythm     * 0.10)
    end

    # ハイトーンボイス: 音程 + ミックスボイス
    # 重視: pitch_score (key indicator), mix_voice_score, overall
    def score_high_tone
      (pitch        * 0.50 +
       eff_mix_voice * 0.25 +
       overall       * 0.15 +
       expression    * 0.10)
    end

    # クリスタルボイス: 透明感 (リラックス) + クリーンな音程
    # 重視: relax_score (key indicator), pitch
    # 声量が高いほど透明感は下がるため pitch への重みで補正
    def score_crystal
      (eff_relax * 0.45 +
       pitch     * 0.35 +
       overall   * 0.20)
    end

    # ワイルドボイス: 表現 × 緊張度 (どちらか片方だけでは上がらない)
    # ポイント: expression と tension の積を使うことで、
    #   息漏れや単なる高い expression だけではワイルド判定されない
    # また技術スコア (overall + pitch) が高いと penalty を付与し、
    #   "磨かれたパワー" は powerful/charisma に誘導する
    def score_wild
      technique_penalty = [((overall + pitch) / 2.0 - 50), 0].max * 0.3
      raw = (expression * 0.50 +
             tension    * 0.35 +
             eff_volume * 0.15) - technique_penalty
      raw
    end

    # アーティスティックボイス: リズム × 表現 × 発音個性
    # 重視: rhythm (フレージング) + expression + pronunciation
    def score_artistic
      (rhythm           * 0.35 +
       expression       * 0.30 +
       eff_pronunciation * 0.25 +
       overall           * 0.10)
    end

    # カリスマ: 均整の取れた高品質 + 表現の広がり
    # 重視: expression + overall + スコアバランス
    # バランス bonus: 4スコアの最大偏差が小さいほど加点 (バランス = 世界観の完成度)
    def score_charisma
      balance = 100 - [
        (overall - pitch).abs,
        (overall - rhythm).abs,
        (overall - expression).abs
      ].max
      (expression * 0.40 +
       overall    * 0.30 +
       balance    * 0.30)
    end

    # ─────────────────────────────────────────────────
    # 判定理由テキスト
    # ─────────────────────────────────────────────────
    def build_reasoning(scores, main_type, sub_type)
      main_score = scores[main_type]
      sub_score  = scores[sub_type]

      "#{VOICE_TYPE_LABELS[main_type]}（#{main_score}点）が最も高く、" \
        "#{VOICE_TYPE_LABELS[sub_type]}（#{sub_score}点）の要素も持ち合わせています。" \
        "#{reasoning_detail(main_type)}"
    end

    def reasoning_detail(type)
      case type
      when :powerful
        "声量スコア(#{eff_volume.round})と表現スコア(#{expression})の高さが判定の根拠です。"
      when :high_tone
        "音程スコア(#{pitch})とミックスボイス(#{eff_mix_voice.round})の高さが判定の根拠です。"
      when :crystal
        "リラックス(#{eff_relax.round})と音程(#{pitch})のバランスが透明感を示しています。"
      when :wild
        "表現(#{expression})と声の緊張度(#{tension.round})が複合的に高いことが判定の根拠です。"
      when :artistic
        "リズム感(#{rhythm})と表現(#{expression})の組み合わせが個性的なフレージングを示しています。"
      when :charisma
        "表現(#{expression})と全体スコア(#{overall})のバランスが高い総合力を示しています。"
      end
    end
  end
end
