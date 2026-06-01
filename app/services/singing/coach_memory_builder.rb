module Singing
  class CoachMemoryBuilder
    CoachMemory = Struct.new(
      :first_diagnosis_at,
      :growth_type,
      :strongest_growth_label,
      :strongest_growth_delta,
      :max_streak,
      :recent_trend_label,
      :diagnosis_count,
      :weeks_since_start,
      :has_memory,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return empty_memory if @customer.nil?

      diagnoses = @customer.singing_diagnoses
                           .completed
                           .where.not(overall_score: nil)
                           .order(created_at: :asc, id: :asc)

      return empty_memory unless diagnoses.exists?

      all         = diagnoses.to_a
      first       = all.first
      count       = all.size
      growth_type = Singing::GrowthTypeAnalyzer.call(@customer)
      max_streak  = Singing::StreakCalculator.call(@customer)
      weeks       = weeks_since(first.created_at)

      comparison          = Singing::GrowthComparisonAnalyzer.call(@customer)
      strongest_label     = comparison.most_improved_label
      strongest_delta     = comparison.most_improved_delta

      CoachMemory.new(
        first_diagnosis_at:    first.created_at.to_date,
        growth_type:           growth_type,
        strongest_growth_label: strongest_label,
        strongest_growth_delta: strongest_delta,
        max_streak:            max_streak,
        recent_trend_label:    recent_trend_label(all),
        diagnosis_count:       count,
        weeks_since_start:     weeks,
        has_memory:            true
      )
    end

    private

    def weeks_since(time)
      ((Time.current - time) / 1.week).floor.clamp(0, 9999)
    end

    def recent_trend_label(diagnoses)
      return nil if diagnoses.size < 2

      latest   = diagnoses.last
      previous = diagnoses[-2]
      best_delta = 0
      best_label = nil

      { pitch_score: "音程", rhythm_score: "リズム", expression_score: "表現力" }.each do |attr, label|
        cur  = latest.public_send(attr)
        prev = previous.public_send(attr)
        next unless cur && prev

        delta = cur - prev
        if delta > best_delta
          best_delta = delta
          best_label = label
        end
      end

      best_label
    end

    def empty_memory
      CoachMemory.new(
        first_diagnosis_at:     nil,
        growth_type:            nil,
        strongest_growth_label: nil,
        strongest_growth_delta: nil,
        max_streak:             0,
        recent_trend_label:     nil,
        diagnosis_count:        0,
        weeks_since_start:      0,
        has_memory:             false
      )
    end
  end
end
