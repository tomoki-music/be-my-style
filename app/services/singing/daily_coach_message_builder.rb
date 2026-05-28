module Singing
  class DailyCoachMessageBuilder
    Result = Struct.new(:message, :coach_label, :coach_icon, :personality, keyword_init: true)

    COACH_META = {
      "passionate" => { label: "熱血コーチ",     icon: "🔥" },
      "gentle"     => { label: "優しい先生",     icon: "🌿" },
      "artist"     => { label: "アーティスト",   icon: "🎨" }
    }.freeze

    # メッセージバンク: context_key => { personality => [messages] }
    MESSAGES = {
      # 3日以上連続
      streak_3plus: {
        "passionate" => [
          "連続%d日！この勢いを止めるな。歌い続けることが、最大の才能だ。",
          "%d日連続！毎日続ける人間だけが見える景色がある。今日も行こう！"
        ],
        "gentle"     => [
          "%d日続いていますね。その一歩一歩が、確かな力になっています。",
          "連続%d日。焦らず、自分のペースで積み重ねてきた証です。今日も一緒に。"
        ],
        "artist"     => [
          "%d日のリズム。それが君だけの音楽になっていく。",
          "続けることは、アーティストの言葉だ。%d日、君はちゃんと歌っている。"
        ]
      },
      # 最近リズムが伸びた
      rhythm_up: {
        "passionate" => [
          "リズムが上がってる！次は表現で化けろ。お前はまだ本気じゃない！",
          "リズムスコアが伸びた。練習が実ってる証拠だ。次のステージへ行こう！"
        ],
        "gentle"     => [
          "リズムが安定してきました。地道な積み重ねの成果ですね。",
          "リズムの伸びが見えています。体がリズムを覚えてきた証拠かもしれません。"
        ],
        "artist"     => [
          "リズムが変わると、歌の色が変わる。君の音楽が深くなっている。",
          "リズムに乗れると、言葉が生きてくる。その感覚、大切に。"
        ]
      },
      # 最近音程が伸びた
      pitch_up: {
        "passionate" => [
          "音程が上がってる！感覚がつかめてきた証拠だ。もっと高みへ行ける！",
          "ピッチスコア伸びた！努力は裏切らない。次の診断でまた上げよう！"
        ],
        "gentle"     => [
          "音程の安定感が増してきました。聴いていて気持ちいい声になってきています。",
          "音程が伸びていますね。耳が育ってきた証拠だと思います。"
        ],
        "artist"     => [
          "音程が合うと、歌が空気に溶ける。その感覚を忘れないで。",
          "ピッチが安定すると、表現の幅が広がる。君の声が豊かになっている。"
        ]
      },
      # 最近表現力が伸びた
      expression_up: {
        "passionate" => [
          "表現力が上がってる！魂がこもってきた！もっと感情を爆発させろ！",
          "表現スコアが伸びた！歌に気持ちが乗ってきてる。その調子で行け！"
        ],
        "gentle"     => [
          "表現力が豊かになってきました。聴く人の心に届く歌に近づいています。",
          "伝わる歌になってきています。気持ちが声に乗ってきた証拠ですね。"
        ],
        "artist"     => [
          "表現が増えると、歌が物語になる。君の声に色がついてきた。",
          "感情が音になる瞬間、それがアートだ。君はその瞬間に近づいている。"
        ]
      },
      # 最初の診断後（1〜2回）
      early_journey: {
        "passionate" => [
          "最初の一歩、最高だ！ここから成長が始まる。続ければ必ず変わる！",
          "スタートした、それだけで偉い。あとは続けるだけ。一緒に行こう！"
        ],
        "gentle"     => [
          "はじめての診断、お疲れさまでした。ここから少しずつ積み重ねていきましょう。",
          "スタートできたことが一番大事です。無理せず、楽しみながら続けましょう。"
        ],
        "artist"     => [
          "すべての音楽は、最初の一音から始まる。君の旅が始まった。",
          "最初の録音が、いつか一番大切な思い出になる。今日を大事に。"
        ]
      },
      # streak 0 / 診断が数日ぶり
      comeback: {
        "passionate" => [
          "久しぶりだな！でも戻ってきた、それが全てだ。今日から再起動！",
          "戻ってきてくれてよかった。サボった日数より、今日歌う勇気の方が大事だ！"
        ],
        "gentle"     => [
          "また来てくれましたね。少し間が空いても、声は覚えていてくれます。",
          "久しぶりでも大丈夫です。今日、また歌えることが大切です。"
        ],
        "artist"     => [
          "音楽に、久しぶりはない。戻ってきた今日が、次の始まりだ。",
          "空白も、音楽の一部だ。今日また歌う君を、声が待っている。"
        ]
      },
      # 診断なし（初回誘導）
      no_diagnosis: {
        "passionate" => [
          "まだ診断したことがないなら、今日がその日だ。最初の一歩を踏み出せ！",
          "録音して診断する。それだけで、自分の声が見えてくる。やってみよう！"
        ],
        "gentle"     => [
          "はじめての診断が、あなただけの成長記録のスタートになります。",
          "まずは一度、今の声を録音してみましょう。評価ではなく、記録のために。"
        ],
        "artist"     => [
          "録音した瞬間から、音楽が始まる。君の声を聴かせて。",
          "最初の録音が、一番勇気がいる。でもそこからアーティストになる。"
        ]
      }
    }.freeze

    def self.call(customer, summary)
      new(customer, summary).call
    end

    def initialize(customer, summary)
      @customer = customer
      @summary  = summary
      @personality = customer&.singing_coach_personality || "passionate"
    end

    def call
      meta = COACH_META[@personality] || COACH_META["passionate"]
      Result.new(
        message:     build_message,
        coach_label: meta[:label],
        coach_icon:  meta[:icon],
        personality: @personality
      )
    end

    private

    def build_message
      context_key = detect_context
      pool = MESSAGES.dig(context_key, @personality) || MESSAGES.dig(:no_diagnosis, @personality)
      template = pool.sample
      format_message(template)
    end

    def detect_context
      return :no_diagnosis unless @summary&.has_diagnoses

      streak = @summary.streak_days.to_i

      if streak >= 3
        :streak_3plus
      elsif @summary.recent_growth_label == "表現力"
        :expression_up
      elsif @summary.recent_growth_label == "リズム"
        :rhythm_up
      elsif @summary.recent_growth_label == "音程"
        :pitch_up
      elsif @summary.diagnosis_count.to_i <= 2
        :early_journey
      elsif streak == 0
        :comeback
      else
        :early_journey
      end
    end

    def format_message(template)
      streak = @summary&.streak_days.to_i
      template % [streak]
    rescue ArgumentError
      template
    end
  end
end
