module Singing
  class PersonalGrowthRoadmapBuilder
    Roadmap = Struct.new(
      :title,
      :subtitle,
      :steps,
      :coach_message,
      keyword_init: true
    )

    Step = Struct.new(
      :number,
      :label,
      :title,
      :description,
      :challenge_key,
      :status,
      keyword_init: true
    ) do
      def completed?
        status == :completed
      end
    end

    GROWTH_LABELS = {
      pitch_growth: "音程",
      rhythm_growth: "リズム",
      expression_growth: "表現"
    }.freeze

    def self.call(customer, progresses: nil, recommended_journey: nil, include_premium: false, challenges: nil)
      new(
        customer,
        progresses: progresses,
        recommended_journey: recommended_journey,
        include_premium: include_premium,
        challenges: challenges
      ).call
    end

    def initialize(customer, progresses: nil, recommended_journey: nil, include_premium: false, challenges: nil)
      @customer = customer
      @progresses = progresses
      @recommended_journey = recommended_journey
      @include_premium = include_premium
      @challenges = challenges
    end

    def call
      Roadmap.new(
        title: "Personal Growth Roadmap",
        subtitle: "今月はこの順番で、歌う楽しさを少しずつ育てていこう。",
        steps: build_steps,
        coach_message: coach_message
      )
    end

    private

    def build_steps
      steps =
        if all_challenges_completed?
          reflection_steps
        elsif diagnosis_count < 3
          early_steps
        else
          active_steps
        end

      steps.first(3).each_with_index.map do |step, index|
        Step.new(step.to_h.merge(number: index + 1, label: "STEP #{index + 1}"))
      end
    end

    def early_steps
      [
        {
          title: "今月の声を3回残す",
          description: "まずは上手さより、今の声を記録することから。歌う回数が増えるほど、自分の調子が見えやすくなります。",
          challenge_key: :diagnosis_5,
          status: diagnosis_count.positive? ? :completed : :current
        },
        recommended_step(status: diagnosis_count.positive? ? :current : :upcoming),
        {
          title: "できたことをひとつ振り返る",
          description: "診断のあとに、良かったところをひとつだけ言葉にしてみよう。小さな肯定感が次の挑戦を支えてくれます。",
          challenge_key: :reflection,
          status: :upcoming
        }
      ].compact
    end

    def active_steps
      [
        recommended_step(status: :current),
        growth_step,
        {
          title: "応援と振り返りにつなげる",
          description: "挑戦できた日は、自分にも仲間にも小さな応援を向けてみよう。続ける空気が、歌う楽しさを育てます。",
          challenge_key: :cheer_reflection,
          status: :upcoming
        }
      ].compact
    end

    def reflection_steps
      [
        {
          title: "今月の挑戦を振り返る",
          description: "達成できた挑戦を眺めて、続けられた自分をちゃんと受け取ろう。次の成長は、その実感から始まります。",
          challenge_key: :monthly_reflection,
          status: :completed
        },
        {
          title: "仲間の挑戦を応援する",
          description: "誰かの一歩に拍手を送ると、自分の挑戦も少し温かくなります。歌はひとりでも、成長は循環できます。",
          challenge_key: :cheer,
          status: :current
        },
        {
          title: next_month_step_title,
          description: next_month_step_description,
          challenge_key: next_month_challenge_key,
          status: :upcoming
        }
      ]
    end

    def recommended_step(status:)
      journey = recommended_journey
      return fallback_challenge_step(status: status) if journey.nil?

      challenge = journey.challenge
      {
        title: challenge.title,
        description: journey.reason.presence || journey.message,
        challenge_key: challenge.id,
        status: status
      }
    end

    def fallback_challenge_step(status:)
      {
        title: "続けやすい挑戦をひとつ選ぶ",
        description: "今の気分に合うチャレンジをひとつ選んでみよう。小さく始めるほど、続ける力になります。",
        challenge_key: :choose_challenge,
        status: status
      }
    end

    def growth_step
      growth = strongest_growth_progress
      if growth
        label = GROWTH_LABELS.fetch(growth.challenge.challenge_type, "歌")
        return {
          title: "#{label}の伸びを育てる",
          description: "伸び始めている感覚を、今月の味方にしよう。無理に点を追わず、歌いやすくなった瞬間を探してみてください。",
          challenge_key: growth.challenge.id,
          status: growth.completed ? :completed : :upcoming
        }
      end

      {
        title: "歌いやすいポイントを探す",
        description: "音程・リズム・表現の中で、今日はひとつだけ意識して歌ってみよう。焦点を絞ると変化に気づきやすくなります。",
        challenge_key: :growth_focus,
        status: :upcoming
      }
    end

    def coach_message
      if all_challenges_completed?
        "今月の挑戦をやりきった流れを、次は振り返りと応援に変えていこう。続けてきたこと自体が、もう成長です。"
      elsif diagnosis_count < 3
        "まずは歌う回数を増やして、自分の声と仲良くなる月にしよう。評価より記録、完璧より一歩です。"
      else
        "今月は挑戦、成長、振り返りの順番で進もう。点数だけでは見えない手応えも、ちゃんと積み上がっています。"
      end
    end

    def recommended_journey
      return @recommended_journey unless @recommended_journey.nil?

      @recommended_journey = Singing::RecommendedJourneyBuilder.call(
        @customer,
        progresses: progresses,
        challenges: @challenges,
        include_premium: @include_premium
      )
    end

    def progresses
      @normalized_progresses ||= begin
        return @progresses unless @progresses.nil?

        Singing::ChallengeProgressBuilder.call(@customer, challenges: @challenges)
      end
    end

    def progress_by_type
      @progress_by_type ||= progresses.index_by { |progress| progress.challenge.challenge_type }
    end

    def strongest_growth_progress
      GROWTH_LABELS.keys
        .filter_map { |type| progress_by_type[type] }
        .max_by { |progress| [progress.current_value.to_i, progress.progress_ratio.to_f] }
    end

    def all_challenges_completed?
      progresses.present? && progresses.all?(&:completed)
    end

    def diagnosis_count
      return 0 if @customer.nil?

      @diagnosis_count ||= @customer.singing_diagnoses.completed.count
    rescue NoMethodError
      0
    end

    def next_month_step_title
      @include_premium ? "次の成長記録を深める" : "次に歌いたい曲を決める"
    end

    def next_month_step_description
      if @include_premium
        "今月の記録をもとに、次のテーマを少しだけ深めてみよう。振り返りがあると、挑戦はもっと自分らしくなります。"
      else
        "好きな曲や歌いやすい曲をひとつ選んで、次の挑戦の入口にしよう。楽しめる選曲が継続の近道です。"
      end
    end

    def next_month_challenge_key
      @include_premium ? :deep_reflection : :song_choice
    end
  end
end
