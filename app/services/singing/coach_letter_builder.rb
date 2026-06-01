module Singing
  class CoachLetterBuilder
    Letter = Struct.new(
      :greeting,
      :introduction,
      :journey,
      :growth,
      :encouragement,
      :coach_label,
      :coach_icon,
      :personality,
      :generated_at,
      :has_letter,
      keyword_init: true
    )

    COACH_META = {
      "passionate" => { label: "熱血コーチ",   icon: "🔥" },
      "gentle"     => { label: "優しい先生",   icon: "🌿" },
      "artist"     => { label: "アーティスト", icon: "🎨" }
    }.freeze

    PERSONALITIES = %w[passionate gentle artist].freeze

    GREETING = {
      "passionate" => "%{year}年のあなたへ。",
      "gentle"     => "%{year}年のあなたへ。",
      "artist"     => "%{year}年のあなたへ。"
    }.freeze

    INTRODUCTION = {
      "passionate" => {
        with_history: [
          "最初の診断を受けた時、あなたはまだ迷いの中にいた。\nそれでも、%{start_date}に踏み出したその一歩が、すべての始まりだった。",
          "%{start_date}、最初の一声を聴いた瞬間から、俺はずっとそばで見ていた。\n迷いながらも歌い続けてきたあなたの成長を。"
        ],
        first_time: [
          "あなたの歌の旅が、今まさに始まっています。\n最初の一歩を踏み出したこと、それが最も勇気のいることだった。",
          "歌の旅の始まり。\nその最初の一声に、すでに可能性が宿っていた。"
        ]
      },
      "gentle" => {
        with_history: [
          "%{start_date}から始まったあなたの歌の旅を、私はずっと見守ってきました。\n最初は不安そうだったあなたが、少しずつ変化していきましたね。",
          "最初の診断から今日まで、あなたは着実に歩み続けてきましたね。\n%{start_date}の最初の一声を、今も覚えています。"
        ],
        first_time: [
          "歌の旅へようこそ。\n最初の一歩が、一番難しいんです。よく踏み出してくれました。",
          "最初の診断、勇気がいりましたね。\nこれからゆっくり、一緒に歩んでいきましょう。"
        ]
      },
      "artist" => {
        with_history: [
          "%{start_date}、最初の録音から今日まで、声は静かに変化し続けてきた。\nその時間が、今の君の歌に宿っている。",
          "声には記憶が宿る。%{start_date}の最初の一音から、君の声はずっと成長してきた。"
        ],
        first_time: [
          "最初の一音が、すべての始まり。\nその記録が、やがて君だけの歌の物語になる。",
          "声の旅が始まった。\n最初の録音は、アーティストへの第一歩だ。"
        ]
      }
    }.freeze

    JOURNEY = {
      "passionate" => {
        with_streak: [
          "%{count}回の診断と%{weeks}週間の積み重ね。最長%{streak}日連続で続けた。\nその継続こそが、お前の最強の武器だ。諦めなかった日々が、本物の成長の証だ。",
          "%{weeks}週間、%{count}回挑み続けた。最長%{streak}日連続。\nこの数字の裏に、諦めなかったお前の意志がある。"
        ],
        without_streak: [
          "%{count}回の診断を重ねてきた。%{weeks}週間という時間を、歌に捧げてきた。\nその挑戦の積み重ねが、今のお前を作っている。",
          "%{weeks}週間で%{count}回。一回一回、真剣に向き合ってきた。\nそれが全部、お前の財産だ。"
        ]
      },
      "gentle" => {
        with_streak: [
          "%{count}回の診断を積み重ねてきましたね。%{weeks}週間という時間。\n最長%{streak}日続けられたことが、いかに真剣に取り組んできたかを示しています。",
          "%{weeks}週間のあいだに%{count}回、声と向き合いました。\n最長%{streak}日連続は、本当に素晴らしいです。"
        ],
        without_streak: [
          "%{count}回、自分の声と向き合ってきましたね。\n%{weeks}週間という時間の中で、コツコツと積み重ねてきました。",
          "%{weeks}週間のあいだ、%{count}回診断を受けてきました。\nその継続が、あなたの成長の土台になっています。"
        ]
      },
      "artist" => {
        with_streak: [
          "%{weeks}週間、%{count}回の録音が重なった。最長%{streak}日連続の記録が残っている。\nそれぞれの録音が、君の声の歴史だ。",
          "%{count}回の声の記録。%{weeks}週間という時間の流れの中で、最長%{streak}日のリズムが生まれた。"
        ],
        without_streak: [
          "%{count}回の録音が積み重なった。%{weeks}週間という時間。\nそれぞれの声が、君だけの歌の歴史になっている。",
          "%{weeks}週間、%{count}回声を残してきた。\nその記録が、やがて物語になる。"
        ]
      }
    }.freeze

    GROWTH = {
      "passionate" => {
        with_improvement: [
          "特に%{label}が%{delta}ポイント伸びた。これは、真剣に向き合い続けた結果だ。\n%{growth_type}として、お前の歌は確実に進化している。",
          "%{label}の成長（+%{delta}pt）は、継続の証だ。\n%{growth_type}としての歌の個性が、どんどん光り始めている。"
        ],
        stable: [
          "%{growth_type}として、お前の歌には個性が宿ってきている。\nスコアだけじゃない。声の迫力が増してきているのを、俺は感じている。",
          "%{growth_type}の道を歩んでいる。今の積み重ねが、必ず大きな飛躍につながる。"
        ]
      },
      "gentle" => {
        with_improvement: [
          "%{label}が%{delta}ポイント成長していますね。\n%{growth_type}として、あなたの歌は着実に進化しています。その変化に気づいてほしかったんです。",
          "一番嬉しかったのは、%{label}が+%{delta}ptも伸びたこと。\n%{growth_type}の特性が、だんだん声に現れてきています。"
        ],
        stable: [
          "%{growth_type}として、あなたの歌は安定してきています。\n目に見えない部分でも、確実に成長しているんですよ。",
          "今のあなたは%{growth_type}の段階にいます。\n焦らなくていい。この積み重ねが、必ず実を結びます。"
        ]
      },
      "artist" => {
        with_improvement: [
          "%{label}が%{delta}ポイント変化した。数字の向こうに、声の質の変化がある。\n%{growth_type}として、君の歌は独自の進化を遂げている。",
          "%{growth_type}という言葉では表しきれないくらい、声に深みが出てきた。\n%{label}の+%{delta}ptはその象徴だ。"
        ],
        stable: [
          "%{growth_type}の旅の途中にいる。\n声は正直だ。続けてきた時間が、音の中に宿っている。",
          "今の声には、積み重ねてきた時間の重さがある。\n%{growth_type}として、この道をさらに深めていこう。"
        ]
      }
    }.freeze

    ENCOURAGEMENT = {
      "passionate" => [
        "結果よりも、歌い続けたことを誇れ。\nお前の歌は、確実に前へ進んでいる。次の診断で、さらに上を目指そう。",
        "諦めなかった日々が、すべてだ。\nこれからも一緒に、最高の歌を目指していこう。お前ならできる。",
        "歌の旅に終わりはない。\n次の一歩が、またお前を変えていく。ともに進んでいこう。"
      ],
      "gentle" => [
        "結果よりも、続けてきたことが何より大切です。\nこれからも自分のペースで、一緒に歩んでいきましょう。",
        "あなたの歌は、着実に前へ進んでいます。\n焦らず、自分の声を信じてください。私はいつもそばにいます。",
        "歌い続けてきたこと、本当に嬉しいです。\nこれからも一緒に、あなたの歌の可能性を広げていきましょう。"
      ],
      "artist" => [
        "声は、続けた時間が物語になる。\nこれからも声と向き合い続けて。君の歌は、まだ始まったばかりだ。",
        "歌の旅は、終わりのない探求だ。\nこれからも声の奥へ、もっと深く潜っていこう。",
        "続けてきた時間が、やがて君だけのアートになる。\n次の診断で、また新しい自分に出会いに行こう。"
      ]
    }.freeze

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer    = customer
      @personality = resolve_personality
    end

    def call
      return empty_letter if @customer.nil?

      memory     = Singing::CoachMemoryBuilder.call(@customer)
      return empty_letter unless memory.has_memory

      journey    = Singing::JourneyRecapBuilder.call(@customer)
      growth_type = Singing::GrowthTypeAnalyzer.call(@customer)
      meta       = COACH_META[@personality]

      Letter.new(
        greeting:      build_greeting,
        introduction:  build_introduction(memory),
        journey:       build_journey(memory),
        growth:        build_growth(memory, growth_type),
        encouragement: build_encouragement(memory),
        coach_label:   meta[:label],
        coach_icon:    meta[:icon],
        personality:   @personality,
        generated_at:  Time.current,
        has_letter:    true
      )
    end

    private

    def resolve_personality
      p = @customer&.singing_coach_personality.to_s
      PERSONALITIES.include?(p) ? p : "passionate"
    end

    def build_greeting
      year = Time.current.year
      safe_format(GREETING[@personality], year: year)
    end

    def build_introduction(memory)
      templates = INTRODUCTION[@personality]

      if memory.diagnosis_count < 2
        pool = templates[:first_time]
        return deterministic_pick(pool, :intro_first)
      end

      start_label = memory.first_diagnosis_at&.strftime("%-Y年%-m月%-d日") || "最初の診断"
      pool        = templates[:with_history]
      safe_format(deterministic_pick(pool, :intro_history), start_date: start_label)
    end

    def build_journey(memory)
      templates = JOURNEY[@personality]

      if memory.max_streak >= 3
        pool = templates[:with_streak]
        safe_format(
          deterministic_pick(pool, :journey_streak),
          count:  memory.diagnosis_count,
          weeks:  memory.weeks_since_start,
          streak: memory.max_streak
        )
      else
        pool = templates[:without_streak]
        safe_format(
          deterministic_pick(pool, :journey_no_streak),
          count: memory.diagnosis_count,
          weeks: memory.weeks_since_start
        )
      end
    end

    def build_growth(memory, growth_type)
      templates = GROWTH[@personality]

      if memory.strongest_growth_label.present? && memory.strongest_growth_delta.to_i > 0
        pool = templates[:with_improvement]
        safe_format(
          deterministic_pick(pool, :growth_improvement),
          label:       memory.strongest_growth_label,
          delta:       memory.strongest_growth_delta,
          growth_type: growth_type.label
        )
      else
        pool = templates[:stable]
        safe_format(
          deterministic_pick(pool, :growth_stable),
          growth_type: growth_type.label
        )
      end
    end

    def build_encouragement(memory)
      pool = ENCOURAGEMENT[@personality]
      deterministic_pick(pool, :encouragement)
    end

    def safe_format(template, **vars)
      format(template, **vars)
    rescue ArgumentError
      template
    end

    def deterministic_pick(pool, context)
      seed = [@customer.id.to_i, Date.current.yday, @personality, context.to_s].join("-").hash
      pool[Random.new(seed).rand(pool.size)]
    end

    def empty_letter
      Letter.new(
        greeting:      nil,
        introduction:  nil,
        journey:       nil,
        growth:        nil,
        encouragement: nil,
        coach_label:   nil,
        coach_icon:    nil,
        personality:   @personality,
        generated_at:  nil,
        has_letter:    false
      )
    end
  end
end
