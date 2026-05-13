module Singing
  class ChallengeBadgeService
    Badge = Struct.new(:key, :label, :description, :icon, :state, keyword_init: true)
    Result = Struct.new(:earned_badges, :candidate_badges, keyword_init: true) do
      def present?
        earned_badges.present? || candidate_badges.present?
      end
    end

    TARGET_BADGES = {
      "pitch" => {
        label: "音程チャレンジ達成",
        icon: "🎯",
        earned_description: "音程安定チャレンジを7日間やり切りました。",
        candidate_description: "音程安定チャレンジの完了チェックで獲得できます。"
      },
      "rhythm" => {
        label: "リズムチャレンジ達成",
        icon: "🥁",
        earned_description: "リズム安定チャレンジを7日間やり切りました。",
        candidate_description: "リズム安定チャレンジの完了チェックで獲得できます。"
      },
      "expression" => {
        label: "表現力チャレンジ達成",
        icon: "✨",
        earned_description: "表現力アップチャレンジを7日間やり切りました。",
        candidate_description: "表現力アップチャレンジの完了チェックで獲得できます。"
      }
    }.freeze

    GROWTH_BADGES = [
      {
        key: :growth_plus_10,
        threshold: 10,
        label: "前回より10点アップ",
        icon: "🚀"
      },
      {
        key: :growth_plus_5,
        threshold: 5,
        label: "前回より5点アップ",
        icon: "📈"
      }
    ].freeze

    # FUTURE: 通知やプロフィール常設表示が必要になったら、SingingBadge とは別テーブルで
    # challenge progress / diagnosis_id に紐づけて永続化する。
    def self.call(customer, diagnosis, feedback: nil)
      new(customer, diagnosis, feedback: feedback).call
    end

    def initialize(customer, diagnosis, feedback: nil)
      @customer = customer
      @diagnosis = diagnosis
      @feedback = feedback
    end

    def call
      return nil unless customer.present? && diagnosis&.completed?
      return nil unless progress.present? && previous_diagnosis.present?

      result = Result.new(
        earned_badges: earned_badges,
        candidate_badges: candidate_badges
      )
      result.present? ? result : nil
    end

    private

    attr_reader :customer, :diagnosis, :feedback

    def earned_badges
      badges = []
      badges << target_badge(:earned) if progress.completed? && target_badge_definition
      badges << first_challenge_badge if first_completed_challenge?
      badges << consecutive_diagnosis_badge if completed_diagnosis_count >= 3
      badges.concat(earned_growth_badges)
      badges.compact
    end

    def candidate_badges
      badges = []
      badges << target_badge(:candidate) if !progress.completed? && target_badge_definition
      badges << consecutive_diagnosis_candidate if completed_diagnosis_count == 2
      badges.concat(candidate_growth_badges)
      badges.compact
    end

    def progress
      @progress ||= feedback_progress || previous_progress
    end

    def feedback_progress
      feedback[:progress] if feedback.respond_to?(:[]) && feedback[:progress].present?
    end

    def previous_progress
      customer.singing_ai_challenge_progresses
              .where(target_key: TARGET_BADGES.keys)
              .where("created_at < ?", diagnosis.created_at)
              .where("tried = ? OR completed = ? OR next_diagnosis_planned = ?", true, true, true)
              .order(challenge_month: :desc, updated_at: :desc, id: :desc)
              .first
    end

    def previous_diagnosis
      @previous_diagnosis ||= feedback_previous_diagnosis || scoped_previous_diagnosis
    end

    def feedback_previous_diagnosis
      feedback[:previous_diagnosis] if feedback.respond_to?(:[]) && feedback[:previous_diagnosis].present?
    end

    def scoped_previous_diagnosis
      customer.singing_diagnoses
              .completed
              .where(performance_type: diagnosis.performance_type)
              .where("created_at < ? OR (created_at = ? AND id < ?)", diagnosis.created_at, diagnosis.created_at, diagnosis.id)
              .order(created_at: :desc, id: :desc)
              .first
    end

    def target_badge_definition
      TARGET_BADGES[progress.target_key]
    end

    def target_badge(state)
      definition = target_badge_definition
      Badge.new(
        key: :"#{progress.target_key}_challenge_completed",
        label: definition[:label],
        description: definition[:"#{state}_description"],
        icon: definition[:icon],
        state: state
      )
    end

    def first_challenge_badge
      Badge.new(
        key: :first_ai_challenge_completed,
        label: "初めてのAIチャレンジ達成",
        description: "最初のAIチャレンジを完了しました。次の診断で成果を見ていきましょう。",
        icon: "🏅",
        state: :earned
      )
    end

    def first_completed_challenge?
      return false unless progress.completed?

      !customer.singing_ai_challenge_progresses
               .where(target_key: TARGET_BADGES.keys)
               .where(completed: true)
               .where("created_at < ?", progress.created_at)
               .exists?
    end

    def completed_diagnosis_count
      @completed_diagnosis_count ||= customer.singing_diagnoses
                                             .completed
                                             .where(performance_type: diagnosis.performance_type)
                                             .where("created_at <= ?", diagnosis.created_at)
                                             .count
    end

    def consecutive_diagnosis_badge
      Badge.new(
        key: :three_consecutive_diagnoses,
        label: "3回連続診断",
        description: "同じ診断対象で3回続けて診断し、変化を確認できました。",
        icon: "🔥",
        state: :earned
      )
    end

    def consecutive_diagnosis_candidate
      Badge.new(
        key: :three_consecutive_diagnoses,
        label: "3回連続診断",
        description: "あと1回の診断で、3回連続診断バッジを狙えます。",
        icon: "🔥",
        state: :candidate
      )
    end

    def earned_growth_badges
      GROWTH_BADGES.filter_map do |definition|
        next unless score_delta >= definition[:threshold]

        growth_badge(definition, :earned, "前回のAIチャレンジ対象スコアから +#{score_delta} 点アップしました。")
      end
    end

    def candidate_growth_badges
      return [] unless score_delta.positive?

      GROWTH_BADGES.filter_map do |definition|
        next if score_delta >= definition[:threshold]

        remaining = definition[:threshold] - score_delta
        growth_badge(definition, :candidate, "あと#{remaining}点アップで獲得できます。")
      end
    end

    def growth_badge(definition, state, description)
      Badge.new(
        key: definition[:key],
        label: definition[:label],
        description: description,
        icon: definition[:icon],
        state: state
      )
    end

    def score_delta
      @score_delta ||= if feedback.respond_to?(:[]) && feedback[:delta].present?
        feedback[:delta].to_i
      else
        target = SingingDiagnoses::ChallengeResultFeedback::TARGETS[progress.target_key]
        current_score = diagnosis.public_send(target[:score_key]) if target
        previous_score = previous_diagnosis.public_send(target[:score_key]) if target

        current_score.nil? || previous_score.nil? ? 0 : current_score.to_i - previous_score.to_i
      end
    end
  end
end
