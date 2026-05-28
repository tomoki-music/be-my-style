module Singing
  class DailyMissionSelector
    Result = Struct.new(:title, :body, keyword_init: true)

    # diagnosis の弱点スコア閾値
    WEAK_SCORE_THRESHOLD = 65

    MISSIONS = {
      rhythm: [
        { title: "リズムだけ集中する3分",      body: "今日は音程を気にせず、リズムに乗ることだけを意識して歌ってみましょう。" },
        { title: "手拍子しながら歌ってみよう",  body: "手でリズムをとりながら歌うと、体でビートを感じやすくなります。" },
        { title: "サビだけ2回通す",             body: "サビのリズムを2回繰り返すだけ。短くていいので、リズム感を確認しましょう。" }
      ],
      pitch: [
        { title: "ゆっくりめに歌ってみよう",    body: "少しテンポを落として歌うと、音程を丁寧に確認しやすくなります。" },
        { title: "Aメロだけ丁寧に録音",         body: "Aメロ1回分だけ。細かくて大丈夫。今の音程を記録しましょう。" },
        { title: "高音フレーズを1回だけ",       body: "高い音が出てくる箇所を1フレーズだけ。力まず、息で支える感覚を試して。" }
      ],
      expression: [
        { title: "感情を乗せて1番だけ",         body: "歌詞の意味を思い浮かべながら、1番だけ気持ちを込めて歌ってみましょう。" },
        { title: "強弱をつけて歌ってみよう",    body: "サビは少し大きく、Aメロは少し抑えて。その差を意識するだけでOKです。" },
        { title: "好きなフレーズを1行だけ",     body: "お気に入りのフレーズを1行。そこに全部の気持ちを入れてみましょう。" }
      ],
      general: [
        { title: "3分だけ声を出してみよう",     body: "録音しなくて大丈夫。3分だけ歌う習慣が、大きな変化につながります。" },
        { title: "今日の声を録音してみよう",    body: "上手く歌おうとしなくていい。今日の声をそのまま残しておきましょう。" },
        { title: "好きな曲を1番だけ",           body: "特別な練習をしなくていい。好きな曲を1番歌うだけで今日は十分です。" },
        { title: "ハミングで曲を通してみよう",  body: "歌詞を気にせずハミングで通すと、メロディのラインが聴こえてきます。" }
      ],
      no_diagnosis: [
        { title: "まず録音してみよう",           body: "どんな状態でも大丈夫。今の声を1回録音することがすべての始まりです。" },
        { title: "好きな曲を1番だけ",           body: "まずは好きな曲を1番だけ。上手く歌おうとしなくていい。声を出すことが大事。" },
        { title: "3分だけ声を出す",             body: "診断の前に、声を出す習慣を作りましょう。3分でOKです。" }
      ]
    }.freeze

    def self.call(latest_diagnosis)
      new(latest_diagnosis).call
    end

    def initialize(latest_diagnosis)
      @diagnosis = latest_diagnosis
    end

    def call
      key = detect_mission_key
      pool = MISSIONS[key] || MISSIONS[:general]
      attrs = pool.sample
      Result.new(**attrs)
    end

    private

    def detect_mission_key
      return :no_diagnosis if @diagnosis.nil?

      weakest = weakest_area
      return weakest if weakest

      :general
    end

    def weakest_area
      scores = {
        rhythm:     @diagnosis.rhythm_score,
        pitch:      @diagnosis.pitch_score,
        expression: @diagnosis.expression_score
      }.compact

      return nil if scores.empty?

      min_attr, min_val = scores.min_by { |_, v| v }
      min_val < WEAK_SCORE_THRESHOLD ? min_attr : nil
    end
  end
end
