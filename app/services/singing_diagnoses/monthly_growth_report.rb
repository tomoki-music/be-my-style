module SingingDiagnoses
  class MonthlyGrowthReport
    SCORE_LABELS = {
      "pitch" => "音程",
      "rhythm" => "リズム",
      "expression" => "表現"
    }.freeze

    FOCUS_MESSAGES = {
      "pitch" => "今月は音程安定を重点的に練習しましょう。",
      "rhythm" => "今月はリズム安定を重点的に練習しましょう。",
      "expression" => "今月は表現力アップを重点的に練習しましょう。"
    }.freeze

    SCORE_KEYS = SCORE_LABELS.keys.freeze

    def initialize(customer, reference_time: Time.current)
      @customer = customer
      @reference_time = reference_time
    end

    def call
      current_scope = diagnoses_for(reference_time.all_month)
      previous_scope = diagnoses_for(reference_time.prev_month.all_month)
      current_averages = score_averages(current_scope)
      previous_averages = score_averages(previous_scope)
      best_growth_key = best_growth_key(current_averages, previous_averages)
      focus_key = focus_key(current_averages)

      {
        current_month_count: current_scope.count,
        previous_month_count: previous_scope.count,
        overall_delta: delta(current_averages["overall"], previous_averages["overall"]),
        best_growth_key: best_growth_key,
        best_growth_label: label_for(best_growth_key),
        best_growth_delta: delta(current_averages[best_growth_key], previous_averages[best_growth_key]),
        focus_key: focus_key,
        focus_label: label_for(focus_key),
        focus_message: FOCUS_MESSAGES.fetch(focus_key),
        has_enough_data: current_scope.exists? && previous_scope.exists?
      }
    end

    private

    attr_reader :customer, :reference_time

    def diagnoses_for(range)
      customer.singing_diagnoses.completed.where(created_at: range)
    end

    def score_averages(scope)
      {
        "overall" => average(scope, :overall_score),
        "pitch" => average(scope, :pitch_score),
        "rhythm" => average(scope, :rhythm_score),
        "expression" => average(scope, :expression_score)
      }
    end

    def average(scope, score_key)
      scope.average(score_key)&.round
    end

    def best_growth_key(current_averages, previous_averages)
      SCORE_KEYS.max_by { |key| delta(current_averages[key], previous_averages[key]) }
    end

    def focus_key(current_averages)
      SCORE_KEYS.min_by { |key| current_averages[key] || 0 }
    end

    def delta(current_value, previous_value)
      current_value.to_i - previous_value.to_i
    end

    def label_for(key)
      SCORE_LABELS.fetch(key)
    end
  end
end
