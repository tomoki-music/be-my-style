module Singing
  class YearRecapBuilder
    Result = Struct.new(
      :year,
      :diagnosis_count,
      :max_streak,
      :growth_type,
      :most_improved_label,
      :most_improved_delta,
      :personal_best_score,
      :personal_best_date,
      :most_active_month,
      :most_active_month_count,
      :most_active_month_label,
      :first_diagnosis_date,
      :milestones,
      :ai_summary,
      :streak_message,
      :coach_reflection,
      :has_recap,
      keyword_init: true
    )

    def self.call(customer, year: Time.current.year)
      new(customer, year: year).call
    end

    def initialize(customer, year:)
      @customer = customer
      @year     = year
    end

    def call
      return empty_result if @customer.nil?

      comparison = Singing::YearGrowthComparisonAnalyzer.call(@customer, year: @year)
      return empty_result if comparison.diagnosis_count.zero?

      growth_type = Singing::GrowthTypeAnalyzer.call(@customer)
      narrator    = Singing::YearRecapNarrator.call(
        customer_id:         @customer.id,
        year:                @year,
        personality:         @customer.singing_coach_personality,
        diagnosis_count:     comparison.diagnosis_count,
        most_improved_label: comparison.most_improved_label,
        most_improved_delta: comparison.most_improved_delta,
        max_streak:          comparison.max_streak
      )

      Result.new(
        year:                    @year,
        diagnosis_count:         comparison.diagnosis_count,
        max_streak:              comparison.max_streak,
        growth_type:             growth_type,
        most_improved_label:     comparison.most_improved_label,
        most_improved_delta:     comparison.most_improved_delta,
        personal_best_score:     comparison.personal_best_score,
        personal_best_date:      comparison.personal_best_date,
        most_active_month:       comparison.most_active_month,
        most_active_month_count: comparison.most_active_month_count,
        most_active_month_label: comparison.most_active_month_label,
        first_diagnosis_date:    comparison.first_diagnosis_date,
        milestones:              comparison.milestones,
        ai_summary:              narrator[:ai_summary],
        streak_message:          narrator[:streak_message],
        coach_reflection:        narrator[:coach_reflection],
        has_recap:               true
      )
    end

    private

    def empty_result
      Result.new(
        year:                    @year,
        diagnosis_count:         0,
        max_streak:              0,
        growth_type:             nil,
        most_improved_label:     nil,
        most_improved_delta:     nil,
        personal_best_score:     nil,
        personal_best_date:      nil,
        most_active_month:       nil,
        most_active_month_count: nil,
        most_active_month_label: nil,
        first_diagnosis_date:    nil,
        milestones:              [],
        ai_summary:              nil,
        streak_message:          nil,
        coach_reflection:        nil,
        has_recap:               false
      )
    end
  end
end
