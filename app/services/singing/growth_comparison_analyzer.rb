module Singing
  class GrowthComparisonAnalyzer
    SCORE_KEYS = %i[pitch_score rhythm_score expression_score overall_score].freeze

    SCORE_LABELS = {
      overall_score:    "総合スコア",
      pitch_score:      "音程",
      rhythm_score:     "リズム",
      expression_score: "表現力"
    }.freeze

    Result = Struct.new(
      :has_comparison,
      :first_scores,
      :recent_scores,
      :deltas,
      :most_improved_key,
      :most_improved_label,
      :most_improved_delta,
      :weeks_since_start,
      :diagnosis_count,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return no_comparison_result if @customer.nil?

      diagnoses = @customer.singing_diagnoses
                           .completed
                           .where.not(overall_score: nil)
                           .order(created_at: :asc, id: :asc)
                           .to_a

      count = diagnoses.size
      return no_comparison_result(count: count) if count < 2

      first_group, recent_group = select_groups(diagnoses, count)

      first_scores  = average_scores(first_group)
      recent_scores = average_scores(recent_group)
      deltas        = compute_deltas(first_scores, recent_scores)
      best_key, best_delta = best_improvement(deltas)

      weeks = ((Time.current - diagnoses.first.created_at) / 1.week).to_i
      weeks = weeks.clamp(0, 999)

      Result.new(
        has_comparison:      true,
        first_scores:        first_scores,
        recent_scores:       recent_scores,
        deltas:              deltas,
        most_improved_key:   best_key,
        most_improved_label: best_key ? SCORE_LABELS[best_key] : nil,
        most_improved_delta: best_delta,
        weeks_since_start:   weeks,
        diagnosis_count:     count
      )
    end

    private

    def select_groups(diagnoses, count)
      if count >= 6
        [diagnoses.first(3), diagnoses.last(3)]
      else
        [[diagnoses.first], [diagnoses.last]]
      end
    end

    def average_scores(group)
      SCORE_KEYS.each_with_object({}) do |key, hash|
        values = group.map { |d| d.public_send(key) }.compact
        hash[key] = values.empty? ? nil : values.sum.to_f / values.size
      end
    end

    def compute_deltas(first_scores, recent_scores)
      SCORE_KEYS.each_with_object({}) do |key, hash|
        f = first_scores[key]
        r = recent_scores[key]
        hash[key] = (f && r) ? (r - f).round : nil
      end
    end

    def best_improvement(deltas)
      best_key   = nil
      best_delta = 0

      deltas.each do |key, delta|
        next if delta.nil?
        if delta > best_delta
          best_delta = delta
          best_key   = key
        end
      end

      [best_key, best_key ? best_delta : nil]
    end

    def no_comparison_result(count: 0)
      Result.new(
        has_comparison:      false,
        first_scores:        {},
        recent_scores:       {},
        deltas:              {},
        most_improved_key:   nil,
        most_improved_label: nil,
        most_improved_delta: nil,
        weeks_since_start:   0,
        diagnosis_count:     count
      )
    end
  end
end
