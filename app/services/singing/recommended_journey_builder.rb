module Singing
  class RecommendedJourneyBuilder
    Result = Struct.new(
      :challenge,
      :progress,
      :coach_label,
      :coach_icon,
      :title,
      :message,
      :reason,
      :action_label,
      keyword_init: true
    )

    COACH_META = Singing::DailyCoachMessageBuilder::COACH_META

    MESSAGE_BY_TYPE = {
      streak: {
        title: "続ける流れを育てよう",
        message: "歌う日を少しずつつなげると、自分の声の変化に気づきやすくなります。",
        reason: "今のペースを大切にしながら、継続のリズムを作れそうです。"
      },
      diagnosis_count: {
        title: "今週の声をもう少し残そう",
        message: "回数を重ねるほど、調子の良い日や歌いやすい感覚が見つかっていきます。",
        reason: "まずは挑戦の回数を増やすと、成長のきっかけを見つけやすくなります。"
      },
      pitch_growth: {
        title: "音程の安定感を伸ばそう",
        message: "音の当たり方が整うと、歌っている自分も聴いている人も気持ちよくなります。",
        reason: "少しだけ音程に意識を向けると、次の成長が見えやすそうです。"
      },
      rhythm_growth: {
        title: "リズムに乗る楽しさを広げよう",
        message: "リズムが整うと、言葉やメロディが前に進みやすくなります。",
        reason: "今はリズムの土台を育てる挑戦が、歌う楽しさにつながりそうです。"
      },
      expression_growth: {
        title: "表現の色を増やそう",
        message: "声に気持ちを乗せるほど、その歌らしさが少しずつ立ち上がります。",
        reason: "ここを伸ばすと、点数だけではない自分らしい歌の手応えが増えそうです。"
      },
      theme: {
        title: "好きな曲で挑戦を続けよう",
        message: "好きなジャンルで続けると、挑戦がもっと自然に日常へなじみます。",
        reason: "楽しめる曲を選ぶことが、継続の一番近い入口になりそうです。"
      }
    }.freeze

    def self.call(customer, progresses: nil, challenges: nil, include_premium: false)
      new(customer, progresses: progresses, challenges: challenges, include_premium: include_premium).call
    end

    def initialize(customer, progresses: nil, challenges: nil, include_premium: false)
      @customer = customer
      @progresses = progresses
      @challenges = challenges
      @include_premium = include_premium
    end

    def call
      return nil if @customer.nil?

      progress = pick_progress
      return nil if progress.nil?

      challenge = progress.challenge
      meta = coach_meta
      copy = MESSAGE_BY_TYPE.fetch(challenge.challenge_type, MESSAGE_BY_TYPE[:diagnosis_count])

      Result.new(
        challenge: challenge,
        progress: progress,
        coach_label: meta[:label],
        coach_icon: meta[:icon],
        title: copy[:title],
        message: copy[:message],
        reason: build_reason(copy[:reason], progress),
        action_label: action_label(progress)
      )
    end

    private

    def pick_progress
      candidates = normalized_progresses.reject(&:completed)
      candidates = candidates.reject { |progress| progress.challenge.premium_only? } unless @include_premium
      return nil if candidates.empty?

      candidates.max_by { |progress| score(progress) }
    end

    def normalized_progresses
      @normalized_progresses ||= begin
        return @progresses unless @progresses.nil?

        Singing::ChallengeProgressBuilder.call(@customer, challenges: @challenges)
      end
    end

    def score(progress)
      ratio = progress.progress_ratio.to_f
      type_priority = {
        diagnosis_count: 6,
        streak: 5,
        expression_growth: 4,
        rhythm_growth: 3,
        pitch_growth: 2,
        theme: 1
      }.fetch(progress.challenge.challenge_type, 0)

      progress.current_value.to_i.positive? ? 100 + ratio : type_priority
    end

    def build_reason(base_reason, progress)
      return base_reason if progress.current_value.to_i.zero?

      "すでに #{progress.progress_label} まで進んでいます。#{base_reason}"
    end

    def action_label(progress)
      progress.current_value.to_i.zero? ? "この挑戦を始める" : "続きを進める"
    end

    def coach_meta
      personality = @customer&.singing_coach_personality.to_s
      COACH_META[personality] || COACH_META["passionate"]
    end
  end
end
