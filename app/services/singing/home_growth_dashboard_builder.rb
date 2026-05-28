module Singing
  class HomeGrowthDashboardBuilder
    Result = Struct.new(
      :summary,
      :latest_diagnosis,
      :next_mission_title,
      :next_mission_body,
      :has_diagnoses,
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

      summary = Singing::JourneySummaryBuilder.call(@customer)
      return empty_result unless summary.has_diagnoses

      latest = @customer.singing_diagnoses
                        .completed
                        .where.not(overall_score: nil)
                        .order(created_at: :desc, id: :desc)
                        .first

      Result.new(
        summary:             summary,
        latest_diagnosis:    latest,
        next_mission_title:  latest&.next_mission_title.presence,
        next_mission_body:   latest&.next_mission_body.presence,
        has_diagnoses:       true
      )
    end

    private

    def empty_result
      Result.new(
        summary:            Singing::JourneySummaryBuilder.call(nil),
        latest_diagnosis:   nil,
        next_mission_title: nil,
        next_mission_body:  nil,
        has_diagnoses:      false
      )
    end
  end
end
