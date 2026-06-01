module Singing
  class CoachReflectionBuilder
    Result = Struct.new(
      :remember,
      :recognize,
      :next_step,
      :full_message,
      :coach_icon,
      :coach_label,
      :has_reflection,
      keyword_init: true
    )

    PERSONALITIES = %w[passionate gentle artist].freeze

    COACH_META = {
      "passionate" => { label: "熱血コーチ",   icon: "🔥" },
      "gentle"     => { label: "優しい先生",   icon: "🌿" },
      "artist"     => { label: "アーティスト", icon: "🎨" }
    }.freeze

    # ① Remember — 過去を思い出す
    REMEMBER = {
      "passionate" => {
        with_growth: [
          "%{weeks}週間前から歌い続けてきた。%{label}が伸びているのは、継続の証だ。",
          "最初の診断から%{weeks}週間。その努力が確かに実ってきている。"
        ],
        no_growth: [
          "%{count}回の診断を積み重ねてきた。この継続が、お前の最大の武器だ。",
          "最初の一声から、今日まで諦めなかった。それがすべてだ。"
        ],
        early: [
          "最初の一歩、それが一番大切だ。",
          "始まりの声が、すべての始まりだ。"
        ]
      },
      "gentle" => {
        with_growth: [
          "%{weeks}週間前から診断を続けてきましたね。%{label}の成長が見えています。",
          "最初から今まで、着実に積み重ねてきました。"
        ],
        no_growth: [
          "%{count}回、自分の声と向き合ってきましたね。",
          "続けること自体が、大きな成長です。"
        ],
        early: [
          "最初の診断、よく踏み出せました。",
          "はじめの一歩が、一番難しいんです。"
        ]
      },
      "artist" => {
        with_growth: [
          "%{weeks}週間、声と向き合い続けた。その時間が、今の君の歌に宿っている。",
          "最初の録音から%{weeks}週間。声は静かに進化している。"
        ],
        no_growth: [
          "%{count}回の診断が、君だけの歌の歴史だ。",
          "続けた記録が、やがて物語になる。"
        ],
        early: [
          "最初の一音から、音楽は始まる。",
          "最初の録音が、一番大切な章だ。"
        ]
      }
    }.freeze

    # ② Recognize — 現在を認識する
    RECOGNIZE = {
      "passionate" => {
        trending: [
          "最近は%{trend}が上がってる。感覚がつかめてきた証拠だ！",
          "%{trend}スコアが伸びている。練習の成果が出てきているぞ！"
        ],
        stable: [
          "今の状態は安定している。ここから更に高みへ行けるぞ。",
          "総合スコアがしっかり積み上がってきた。基礎ができている。"
        ],
        streak: [
          "%{streak}日連続！この調子を続けていけば、必ず次のステージに行ける。",
          "連続%{streak}日。継続こそが、お前の最強の武器だ！"
        ]
      },
      "gentle" => {
        trending: [
          "最近、%{trend}が安定してきていますね。",
          "%{trend}に成長が見えています。とても良い変化です。"
        ],
        stable: [
          "スコアが着実に積み上がっています。",
          "今の声の状態はとても安定しています。"
        ],
        streak: [
          "%{streak}日続けていますね。とても素晴らしいです。",
          "連続%{streak}日、コツコツ続けてきた結果が出ています。"
        ]
      },
      "artist" => {
        trending: [
          "%{trend}が変化している。その感覚を大事にして。",
          "最近、%{trend}に面白い変化がある。続けると見えてくるものがある。"
        ],
        stable: [
          "今の声には、積み重ねた時間の重みがある。",
          "スコアだけじゃない。声に深みが出てきている。"
        ],
        streak: [
          "%{streak}日、声と向き合い続けた。その継続がアーティストを作る。",
          "連続%{streak}日のリズムが、君の歌の個性になっていく。"
        ]
      }
    }.freeze

    # ③ Next Step — 未来へ導く
    NEXT_STEP = {
      "passionate" => {
        pitch: [
          "次は音程の精度をさらに上げろ。正確さが歌の説得力を生む！",
          "音程をさらに磨け。その先に、本物のシンガーがいる。"
        ],
        rhythm: [
          "次はリズムの安定感を徹底的に鍛えろ。グルーヴが出たとき、歌が別物になる！",
          "リズムを磨け。ノリが出たとき、全体が一気に変わる。"
        ],
        expression: [
          "次は表現力だ。感情を声に乗せるのが、お前の次のミッションだ！",
          "表現力を磨け。それが伝わる歌への道だ。"
        ],
        overall: [
          "全体をバランスよく磨いていけ。お前はまだ伸びる！",
          "次の診断で、さらに上を目指せ。ポテンシャルはまだある！"
        ]
      },
      "gentle" => {
        pitch: [
          "次は音程の安定感をさらに意識してみましょう。",
          "音程に意識を向けると、より安定した歌声になりますよ。"
        ],
        rhythm: [
          "次はリズムの入りを少し意識してみましょう。",
          "リズムをもう一段階安定させると、歌全体がさらに良くなります。"
        ],
        expression: [
          "次は気持ちを声に乗せることを意識してみましょう。",
          "表現力を少し意識すると、伝わる歌に近づきますよ。"
        ],
        overall: [
          "引き続き、自分のペースで積み重ねていきましょう。",
          "次の診断でも、一緒に成長を確認していきましょう。"
        ]
      },
      "artist" => {
        pitch: [
          "音程が合うと、声が空気に溶ける。その感覚を探してみて。",
          "音程の安定は、表現の土台だ。次はそこを磨いていこう。"
        ],
        rhythm: [
          "リズムに乗ったとき、言葉が生きてくる。その感覚を大切に。",
          "自分だけのグルーヴを探してみて。それが君の音楽になる。"
        ],
        expression: [
          "声で物語を語れるとき、歌はアートになる。次はそこへ。",
          "感情を音にする練習を。その先に、誰にも真似できない声がある。"
        ],
        overall: [
          "声の旅は続く。次の診断で、また新しい自分に会いに行こう。",
          "歌い続けることが、アーティストへの道だ。"
        ]
      }
    }.freeze

    def self.call(customer, diagnosis, memory)
      new(customer, diagnosis, memory).call
    end

    def initialize(customer, diagnosis, memory)
      @customer    = customer
      @diagnosis   = diagnosis
      @memory      = memory
      @personality = resolve_personality
    end

    def call
      return empty_result if @customer.nil? || @memory.nil? || !@memory.has_memory

      meta      = COACH_META[@personality] || COACH_META["passionate"]
      remember  = build_remember
      recognize = build_recognize
      next_step = build_next_step
      full      = [remember, recognize, next_step].compact.join("\n\n")

      Result.new(
        remember:       remember,
        recognize:      recognize,
        next_step:      next_step,
        full_message:   full,
        coach_icon:     meta[:icon],
        coach_label:    meta[:label],
        has_reflection: true
      )
    end

    private

    def resolve_personality
      p = @customer&.singing_coach_personality.to_s
      PERSONALITIES.include?(p) ? p : "passionate"
    end

    def build_remember
      messages = REMEMBER[@personality]

      if @memory.diagnosis_count < 2
        pool = messages[:early]
        return deterministic_pick(pool, :remember_early)
      end

      if @memory.strongest_growth_label.present? && @memory.strongest_growth_delta.to_i > 0
        pool = messages[:with_growth]
        template = deterministic_pick(pool, :remember_growth)
        return safe_format(template,
                           weeks: @memory.weeks_since_start,
                           label: @memory.strongest_growth_label,
                           count: @memory.diagnosis_count)
      end

      pool = messages[:no_growth]
      template = deterministic_pick(pool, :remember_no_growth)
      safe_format(template, count: @memory.diagnosis_count)
    end

    def build_recognize
      messages = RECOGNIZE[@personality]

      if @memory.max_streak >= 3
        pool = messages[:streak]
        return safe_format(deterministic_pick(pool, :recognize_streak), streak: @memory.max_streak)
      end

      if @memory.recent_trend_label.present?
        pool = messages[:trending]
        return safe_format(deterministic_pick(pool, :recognize_trending), trend: @memory.recent_trend_label)
      end

      pool = messages[:stable]
      deterministic_pick(pool, :recognize_stable)
    end

    def build_next_step
      messages = NEXT_STEP[@personality]
      pool     = messages[weakest_score_key] || messages[:overall]
      deterministic_pick(pool, :next_step)
    end

    def weakest_score_key
      return :overall if @diagnosis.nil?

      scores = {
        pitch:      @diagnosis.pitch_score,
        rhythm:     @diagnosis.rhythm_score,
        expression: @diagnosis.expression_score
      }.compact

      return :overall if scores.empty?

      scores.min_by { |_, v| v }.first
    end

    def safe_format(template, **vars)
      format(template, **vars)
    rescue ArgumentError
      template
    end

    def deterministic_pick(pool, context)
      seed = [@customer&.id.to_i, Date.current.yday, @personality, context.to_s, @memory.diagnosis_count].join("-").hash
      pool[Random.new(seed).rand(pool.size)]
    end

    def empty_result
      Result.new(
        remember:       nil,
        recognize:      nil,
        next_step:      nil,
        full_message:   nil,
        coach_icon:     nil,
        coach_label:    nil,
        has_reflection: false
      )
    end
  end
end
