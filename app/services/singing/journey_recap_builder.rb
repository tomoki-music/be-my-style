module Singing
  class JourneyRecapBuilder
    Result = Struct.new(
      :growth_story,
      :journey_story,
      :coach_reflection,
      :diagnosis_count,
      :streak_days,
      :most_improved_label,
      :most_improved_delta,
      :has_story,
      keyword_init: true
    )

    def self.call(customer)
      new(customer).call
    end

    def initialize(customer)
      @customer = customer
    end

    def call
      return empty_result if @customer.nil?

      summary    = Singing::JourneySummaryBuilder.call(@customer)
      comparison = Singing::GrowthComparisonAnalyzer.call(@customer)
      narrator   = Singing::GrowthMemoryNarrator.call(@customer, comparison)

      return empty_result unless narrator.has_story

      Result.new(
        growth_story:        narrator.growth_story,
        journey_story:       narrator.journey_story,
        coach_reflection:    narrator.coach_reflection,
        diagnosis_count:     summary.diagnosis_count,
        streak_days:         summary.streak_days,
        most_improved_label: comparison.most_improved_label,
        most_improved_delta: comparison.most_improved_delta,
        has_story:           true
      )
    end

    private

    def empty_result
      Result.new(
        growth_story:        nil,
        journey_story:       nil,
        coach_reflection:    nil,
        diagnosis_count:     0,
        streak_days:         0,
        most_improved_label: nil,
        most_improved_delta: nil,
        has_story:           false
      )
    end
  end
end
