module SingingDiagnoses
  class ChallengeResultFeedback
    TARGETS = {
      "pitch" => {
        score_key: :pitch_score,
        label: "音程",
        challenge_title: "音程安定チャレンジ"
      },
      "rhythm" => {
        score_key: :rhythm_score,
        label: "リズム",
        challenge_title: "リズム安定チャレンジ"
      },
      "expression" => {
        score_key: :expression_score,
        label: "表現",
        challenge_title: "表現力アップチャレンジ"
      }
    }.freeze

    def initialize(customer, diagnosis)
      @customer = customer
      @diagnosis = diagnosis
    end

    def call
      return nil unless customer.present? && diagnosis&.completed?

      progress = previous_progress
      return nil if progress.blank?

      target = TARGETS[progress.target_key]
      return nil if target.blank?

      previous_diagnosis = previous_completed_diagnosis
      return nil if previous_diagnosis.blank?

      current_score = diagnosis.public_send(target[:score_key])
      previous_score = previous_diagnosis.public_send(target[:score_key])
      return nil if current_score.nil? || previous_score.nil?

      delta = current_score.to_i - previous_score.to_i

      {
        progress: progress,
        previous_diagnosis: previous_diagnosis,
        target_key: progress.target_key,
        target_label: target[:label],
        challenge_title: target[:challenge_title],
        previous_score: previous_score.to_i,
        current_score: current_score.to_i,
        delta: delta,
        delta_label: delta_label(delta),
        score_sentence: score_sentence(target[:label], delta),
        message: feedback_message(delta)
      }
    end

    private

    attr_reader :customer, :diagnosis

    def previous_progress
      customer.singing_ai_challenge_progresses
              .where(target_key: TARGETS.keys)
              .where("created_at < ?", diagnosis.created_at)
              .where("tried = ? OR completed = ? OR next_diagnosis_planned = ?", true, true, true)
              .order(challenge_month: :desc, updated_at: :desc, id: :desc)
              .first
    end

    def previous_completed_diagnosis
      customer.singing_diagnoses
              .completed
              .where(performance_type: diagnosis.performance_type)
              .where("created_at < ? OR (created_at = ? AND id < ?)", diagnosis.created_at, diagnosis.created_at, diagnosis.id)
              .order(created_at: :desc, id: :desc)
              .first
    end

    def delta_label(delta)
      return "+#{delta}" if delta.positive?

      delta.to_s
    end

    def score_sentence(target_label, delta)
      if delta.positive?
        "前回より#{target_label}スコアが #{delta_label(delta)} 点アップしています。"
      elsif delta.zero?
        "前回の#{target_label}スコアをキープしています。"
      else
        "#{target_label}スコアは前回比 #{delta_label(delta)} 点です。"
      end
    end

    def feedback_message(delta)
      if delta.positive?
        "少しずつ練習の成果が出ています！"
      elsif delta.zero?
        "スコアを保てています。練習で安定感が育ってきています！"
      else
        "取り組んだポイントは次につながっています。焦らず続けていきましょう！"
      end
    end
  end
end
