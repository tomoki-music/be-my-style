module Singing
  class GrowthMemoryNarrator
    Result = Struct.new(
      :growth_story,
      :journey_story,
      :coach_reflection,
      :has_story,
      keyword_init: true
    )

    PERSONALITIES = %w[passionate gentle artist].freeze

    GROWTH_STORIES = {
      "passionate" => [
        "%{weeks}週間前より%{label}が+%{delta}向上。諦めなかった結果だ。",
        "%{label}が+%{delta}上がっている。これが努力の証だ！",
        "+%{delta}の%{label}。その熱量が数字に現れている。"
      ],
      "gentle" => [
        "%{weeks}週間前より%{label}が+%{delta}成長しています。",
        "%{label}が+%{delta}伸びていますよ。素晴らしい進歩です。",
        "じっくりと%{label}を+%{delta}高めることができています。"
      ],
      "artist" => [
        "声に変化が生まれている。%{weeks}週間前より%{label}が+%{delta}、静かに進化している。",
        "%{label}が+%{delta}。その変化はあなたの声が語っている。",
        "歌うたびに何かが変わっている。%{label}が+%{delta}積み重なっている。"
      ]
    }.freeze

    NO_GROWTH_STORIES = {
      "passionate" => [
        "毎回の積み重ねが、確かな力になっている。続けることが強さだ。",
        "今日の一回が、必ず未来の自分を動かす。"
      ],
      "gentle" => [
        "毎回の積み重ねが、確かな力になっています。",
        "続けること自体が、あなたの成長です。"
      ],
      "artist" => [
        "数字には現れない何かが、歌の中に宿っている。",
        "変化は静かに訪れる。続けることが答えだ。"
      ]
    }.freeze

    EARLY_STORIES = {
      "passionate" => [
        "最初の一歩が、一番大切だ。これからが始まりだ！",
        "まだ始まったばかり。その挑戦が一番の勇気だ。"
      ],
      "gentle" => [
        "最初の一歩が、一番大切です。",
        "まだ始まったばかりです。一緒に進んでいきましょう。"
      ],
      "artist" => [
        "最初の一歩から、ここまで来た。",
        "始まりの声が、すべての始まりだ。"
      ]
    }.freeze

    JOURNEY_STORIES = {
      "passionate" => [
        "%{count}回、自分の声と向き合ってきた。その継続が最大の武器だ！",
        "%{count}回の診断。一つひとつが本物の挑戦だった。"
      ],
      "gentle" => [
        "%{count}回、自分の声と向き合ってきました。",
        "%{count}回の積み重ね、素晴らしいです。"
      ],
      "artist" => [
        "%{count}回、声と向き合ってきた。その記録が物語になっている。",
        "%{count}回の診断が、あなたの歌の歴史だ。"
      ]
    }.freeze

    COACH_REFLECTIONS = {
      "passionate" => [
        "最初の一歩から、ここまで来ましたね。次のステージが待っている！",
        "ここまでの挑戦、本物だ。まだ終わっていない。"
      ],
      "gentle" => [
        "最初の一歩から、ここまで来ましたね。",
        "あなたのペースで、ここまで歩んできました。"
      ],
      "artist" => [
        "最初の一歩から、ここまで来た。声は正直だ。",
        "歌い続けた結果が、今のあなたの声だ。"
      ]
    }.freeze

    def self.call(customer, comparison)
      new(customer, comparison).call
    end

    def initialize(customer, comparison)
      @customer    = customer
      @comparison  = comparison
      @personality = resolve_personality
      @count       = comparison&.diagnosis_count.to_i
    end

    def call
      return empty_result if @customer.nil?
      return empty_result if @comparison.nil?
      return empty_result if @count == 0

      Result.new(
        growth_story:     build_growth_story,
        journey_story:    build_journey_story,
        coach_reflection: build_coach_reflection,
        has_story:        true
      )
    end

    private

    def resolve_personality
      return "passionate" if @customer.nil?

      personality = @customer.singing_coach_personality.to_s
      PERSONALITIES.include?(personality) ? personality : "passionate"
    end

    def build_growth_story
      if @comparison.has_comparison && @comparison.most_improved_delta.to_i > 0
        pool     = GROWTH_STORIES[@personality]
        template = deterministic_pick(pool, :growth)
        format(template,
               weeks: @comparison.weeks_since_start,
               label: @comparison.most_improved_label,
               delta: @comparison.most_improved_delta)
      elsif @count < 2
        pool = EARLY_STORIES[@personality]
        deterministic_pick(pool, :early)
      else
        pool = NO_GROWTH_STORIES[@personality]
        deterministic_pick(pool, :no_growth)
      end
    end

    def build_journey_story
      pool     = JOURNEY_STORIES[@personality]
      template = deterministic_pick(pool, :journey)
      format(template, count: @count)
    end

    def build_coach_reflection
      pool = COACH_REFLECTIONS[@personality]
      deterministic_pick(pool, :reflection)
    end

    # 1日単位で安定する選択（customer_id + 年の何日目 + personality + context + count のハッシュ）
    def deterministic_pick(pool, context)
      seed = [@customer&.id.to_i, Date.current.yday, @personality, context.to_s, @count].join("-").hash
      pool[Random.new(seed).rand(pool.size)]
    end

    def empty_result
      Result.new(
        growth_story:     nil,
        journey_story:    nil,
        coach_reflection: nil,
        has_story:        false
      )
    end
  end
end
