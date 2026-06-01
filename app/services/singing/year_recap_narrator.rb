module Singing
  class YearRecapNarrator
    PERSONALITIES = %w[passionate gentle artist].freeze

    AI_SUMMARIES = {
      "passionate" => {
        high_growth: [
          "%{year}年、あなたは%{count}回歌い切り、%{label}を+%{delta}伸ばした。その数字は、諦めなかった証だ。",
          "%{year}年の%{count}回が、%{label}+%{delta}という現実を作り出した。積み重ねは嘘をつかない。"
        ],
        mid_count: [
          "%{year}年、%{count}回の診断。一回ごとが、自分の限界への挑戦だった。",
          "%{count}回、自分の声に向き合った%{year}年。続けることが、最も難しく、最も価値があることだ。"
        ],
        low_count: [
          "%{year}年、最初の一歩を踏み出した。%{count}回の積み重ねが、次への土台になっている。",
          "%{count}回でも、歌い続けたことに意味がある。%{year}年のあなたは、確かに前進した。"
        ]
      },
      "gentle" => {
        high_growth: [
          "%{year}年、%{count}回も診断してくれましたね。%{label}が+%{delta}伸びた、その変化はちゃんと声に出ています。",
          "%{label}が+%{delta}成長した%{year}年。%{count}回、一緒に歌えたことが嬉しいです。"
        ],
        mid_count: [
          "%{year}年、%{count}回自分の声と向き合いましたね。それだけで、十分素晴らしいことです。",
          "%{count}回の診断が積み重なった%{year}年。焦らず、丁寧に続けてきた証ですね。"
        ],
        low_count: [
          "%{year}年に%{count}回、声を届けてくれましたね。どんな回数でも、続けること自体がとても大切です。",
          "%{count}回から、また始めましょう。%{year}年の歩みは、来年への贈り物です。"
        ]
      },
      "artist" => {
        high_growth: [
          "%{year}年の%{count}回が、%{label}+%{delta}という軌跡を描いた。声は正直だ。",
          "%{count}回の録音が、%{label}に+%{delta}の変化をもたらした。%{year}年、あなたの歌は進化している。"
        ],
        mid_count: [
          "%{year}年、%{count}回の声が記録された。その声は、時間をかけて熟成されている。",
          "%{count}回の診断が、%{year}年のあなたの歌の地図を描いている。"
        ],
        low_count: [
          "%{count}回の声が、%{year}年のページに静かに刻まれている。",
          "%{year}年の%{count}回は、あなたの歌の物語の序章だ。"
        ]
      }
    }.freeze

    STREAK_MESSAGES = {
      "passionate" => [
        "最長%{streak}日連続の継続！それが本当の強さだ。",
        "%{streak}日間、一日も逃さなかった。その意志が、声を変えている。"
      ],
      "gentle" => [
        "最長%{streak}日連続で歌ってくれましたね。継続することが、一番の練習です。",
        "%{streak}日間も続けられたこと、本当に素晴らしいですね。"
      ],
      "artist" => [
        "%{streak}日間の連続が、声の密度を上げている。",
        "最長%{streak}日のStreakは、あなたの歌への誠実さの証だ。"
      ]
    }.freeze

    COACH_REFLECTIONS = {
      "passionate" => [
        "今年の積み重ねが、来年の自分を圧倒的に高める。来年も挑み続けろ。",
        "この1年の戦いは終わった。だが、歌の旅はまだ続く。次のステージへ行こう。"
      ],
      "gentle" => [
        "今年も一緒に歌えて、よかったです。来年も、あなたのペースで続けましょう。",
        "この1年間、よく頑張りましたね。来年も、焦らず一歩ずつ進みましょう。"
      ],
      "artist" => [
        "今年の声は、来年の声の礎になっている。また新しいページを開こう。",
        "1年間の声の旅が終わった。それは次の旅の始まりでもある。"
      ]
    }.freeze

    def self.call(data)
      new(data).call
    end

    def initialize(data)
      @customer_id         = data[:customer_id].to_i
      @year                = data[:year].to_i
      @personality         = resolve_personality(data[:personality])
      @diagnosis_count     = data[:diagnosis_count].to_i
      @most_improved_label = data[:most_improved_label]
      @most_improved_delta = data[:most_improved_delta].to_i
      @max_streak          = data[:max_streak].to_i
    end

    def call
      {
        ai_summary:       build_ai_summary,
        streak_message:   build_streak_message,
        coach_reflection: build_coach_reflection
      }
    end

    private

    def resolve_personality(personality)
      p = personality.to_s
      PERSONALITIES.include?(p) ? p : "passionate"
    end

    def count_tier
      if @diagnosis_count >= 30
        :high_growth
      elsif @diagnosis_count >= 5
        :mid_count
      else
        :low_count
      end
    end

    def build_ai_summary
      tier = count_tier

      if tier == :high_growth && @most_improved_label.present? && @most_improved_delta > 0
        pool     = AI_SUMMARIES[@personality][:high_growth]
        template = deterministic_pick(pool, :summary_high)
        format(template,
               year:   @year,
               count:  @diagnosis_count,
               label:  @most_improved_label,
               delta:  @most_improved_delta)
      elsif tier == :mid_count
        pool     = AI_SUMMARIES[@personality][:mid_count]
        template = deterministic_pick(pool, :summary_mid)
        format(template, year: @year, count: @diagnosis_count)
      else
        pool     = AI_SUMMARIES[@personality][:low_count]
        template = deterministic_pick(pool, :summary_low)
        format(template, year: @year, count: @diagnosis_count)
      end
    end

    def build_streak_message
      return nil if @max_streak < 3

      pool     = STREAK_MESSAGES[@personality]
      template = deterministic_pick(pool, :streak)
      format(template, streak: @max_streak)
    end

    def build_coach_reflection
      pool = COACH_REFLECTIONS[@personality]
      deterministic_pick(pool, :reflection)
    end

    # customer_id + year + personality + context を seed に年単位で安定した選択
    def deterministic_pick(pool, context)
      seed = [@customer_id, @year, @personality, context.to_s].join("-").hash
      pool[Random.new(seed).rand(pool.size)]
    end
  end
end
