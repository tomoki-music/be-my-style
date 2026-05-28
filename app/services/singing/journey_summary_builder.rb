module Singing
  class JourneySummaryBuilder
    Result = Struct.new(
      :diagnosis_count,
      :best_score,
      :latest_score,
      :streak_days,
      :recent_growth_label,
      :recent_growth_delta_label,
      :has_diagnoses,
      keyword_init: true
    )

    SCORE_LABELS = {
      overall_score:    "総合スコア",
      pitch_score:      "音程",
      rhythm_score:     "リズム",
      expression_score: "表現力"
    }.freeze

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return empty_result if @customer.nil?

      diagnoses = @customer.singing_diagnoses
                           .completed
                           .where.not(overall_score: nil)
                           .order(created_at: :desc, id: :desc)

      return empty_result unless diagnoses.exists?

      latest   = diagnoses.first
      best     = diagnoses.maximum(:overall_score)
      count    = diagnoses.count
      streak   = Singing::StreakCalculator.call(@customer)
      growth_label, growth_delta = recent_growth(diagnoses)

      Result.new(
        diagnosis_count:           count,
        best_score:                best,
        latest_score:              latest.overall_score,
        streak_days:               streak,
        recent_growth_label:       growth_label,
        recent_growth_delta_label: growth_delta,
        has_diagnoses:             true
      )
    end

    private

    def empty_result
      Result.new(
        diagnosis_count:           0,
        best_score:                nil,
        latest_score:              nil,
        streak_days:               0,
        recent_growth_label:       nil,
        recent_growth_delta_label: nil,
        has_diagnoses:             false
      )
    end

    def recent_growth(diagnoses)
      latest   = diagnoses.first
      previous = diagnoses.offset(1).first
      return [nil, nil] if previous.nil?

      best_label = nil
      best_delta = 0

      SCORE_LABELS.each_key do |attr|
        current_val  = latest.public_send(attr)
        previous_val = previous.public_send(attr)
        next if current_val.nil? || previous_val.nil?

        delta = current_val - previous_val
        if delta > best_delta
          best_delta = delta
          best_label = SCORE_LABELS[attr]
        end
      end

      return [nil, nil] if best_delta <= 0 || best_label.nil?

      [best_label, "+#{best_delta}"]
    end
  end
end
