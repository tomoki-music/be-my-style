module Singing
  class MonthlyWrappedNarrator
    PERSONALITIES = %w[passionate gentle artist].freeze

    WRAPPED_MESSAGES = {
      "passionate" => {
        high_count: [
          "今月、%{count}回歌い切った。その積み重ねは本物だ。",
          "%{count}回の診断。一つひとつが本物の挑戦だった。"
        ],
        mid_count: [
          "今月、%{count}回自分の声に向き合った。毎回が挑戦だ。",
          "%{count}回、諦めずに続けた。それが本当の強さだ。"
        ],
        low_count: [
          "今月も%{count}回、歌への情熱を絶やさなかった。",
          "%{count}回でも、歌い続けた事実は変わらない。"
        ]
      },
      "gentle" => {
        high_count: [
          "今月、%{count}回自分の声と向き合いました。",
          "%{count}回の診断、本当によく続けましたね。"
        ],
        mid_count: [
          "今月、%{count}回声を聴かせてくれましたね。",
          "%{count}回の積み重ね、丁寧に続けてきましたね。"
        ],
        low_count: [
          "今月も%{count}回、あなたの声を届けてくれました。",
          "%{count}回でも、確かな一歩です。"
        ]
      },
      "artist" => {
        high_count: [
          "今月の%{count}回の声が、あなたの音楽史に静かに刻まれています。",
          "%{count}回。それぞれの声が、物語を紡いでいる。"
        ],
        mid_count: [
          "今月、%{count}回の声が記録された。声は正直だ。",
          "%{count}回の診断が、あなたの歌の地図を描いている。"
        ],
        low_count: [
          "今月の%{count}回は、静かな問いかけだったかもしれない。",
          "%{count}回の声が、今月のページを飾っている。"
        ]
      }
    }.freeze

    GROWTH_MESSAGES = {
      "passionate" => [
        "最も伸びたのは%{label}。+%{delta}の成長が、努力の証だ。",
        "%{label}が+%{delta}向上。声に変化が生まれている。"
      ],
      "gentle" => [
        "最も伸びたのは%{label}です。+%{delta}の成長、素晴らしいですね。",
        "%{label}が+%{delta}伸びました。声に少しずつ感情が宿ってきています。"
      ],
      "artist" => [
        "最も伸びたのは%{label}。+%{delta}、声が変わり始めている。",
        "%{label}が+%{delta}。その変化は、あなたの歌が語っている。"
      ]
    }.freeze

    COACH_REFLECTIONS = {
      "passionate" => [
        "今月の歌は、来月の自分への最高のギフトだ。",
        "続けることが、すべての始まりだ。来月も行こう。"
      ],
      "gentle" => [
        "今月も一緒に歌えて、よかったです。来月もゆっくり続けましょう。",
        "今月の積み重ねが、来月の自分を支えてくれます。"
      ],
      "artist" => [
        "今月の声は、来月の声の礎になっている。",
        "一ヶ月の声の旅が、静かに終わった。また始めよう。"
      ]
    }.freeze

    def self.call(data)
      new(data).call
    end

    def initialize(data)
      @customer_id         = data[:customer_id].to_i
      @year                = data[:year].to_i
      @month               = data[:month].to_i
      @personality         = resolve_personality(data[:personality])
      @diagnosis_count     = data[:diagnosis_count].to_i
      @most_improved_label = data[:most_improved_label]
      @most_improved_delta = data[:most_improved_delta].to_i
    end

    def call
      {
        wrapped_message:  build_wrapped_message,
        coach_reflection: build_coach_reflection
      }
    end

    private

    def resolve_personality(personality)
      p = personality.to_s
      PERSONALITIES.include?(p) ? p : "passionate"
    end

    def count_tier
      if @diagnosis_count >= 15
        :high_count
      elsif @diagnosis_count >= 5
        :mid_count
      else
        :low_count
      end
    end

    def build_wrapped_message
      pool     = WRAPPED_MESSAGES[@personality][count_tier]
      template = deterministic_pick(pool, :wrapped)
      base     = format(template, count: @diagnosis_count)

      if @most_improved_label.present? && @most_improved_delta > 0
        growth_pool     = GROWTH_MESSAGES[@personality]
        growth_template = deterministic_pick(growth_pool, :growth)
        growth_part     = format(growth_template, label: @most_improved_label, delta: @most_improved_delta)
        "#{base}\n#{growth_part}"
      else
        base
      end
    end

    def build_coach_reflection
      pool = COACH_REFLECTIONS[@personality]
      deterministic_pick(pool, :reflection)
    end

    # customer_id + year + month + personality + context を seed に月単位で安定する選択
    def deterministic_pick(pool, context)
      seed = [@customer_id, @year, @month, @personality, context.to_s].join("-").hash
      pool[Random.new(seed).rand(pool.size)]
    end
  end
end
