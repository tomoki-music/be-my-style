module Singing
  class HomeGrowthDashboardBuilder
    Result = Struct.new(
      :summary,
      :latest_diagnosis,
      :next_mission_title,
      :next_mission_body,
      :has_diagnoses,
      :coach_message,
      :daily_mission,
      :singer_rank,
      :singer_rank_progress,
      :singer_next_rank,
      :singing_xp,
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

      latest = @customer.singing_diagnoses
                        .completed
                        .where.not(overall_score: nil)
                        .order(created_at: :desc, id: :desc)
                        .first

      Result.new(
        summary:              summary,
        latest_diagnosis:     latest,
        next_mission_title:   latest&.next_mission_title.presence,
        next_mission_body:    latest&.next_mission_body.presence,
        has_diagnoses:        summary.has_diagnoses,
        coach_message:        Singing::DailyCoachMessageBuilder.call(@customer, summary),
        daily_mission:        Singing::DailyMissionSelector.call(latest),
        singer_rank:          @customer.singer_rank,
        singer_rank_progress: @customer.singer_rank_progress,
        singer_next_rank:     @customer.singer_next_rank,
        singing_xp:           @customer.singing_xp
      )
    end

    private

    def empty_result
      Result.new(
        summary:              Singing::JourneySummaryBuilder.call(nil),
        latest_diagnosis:     nil,
        next_mission_title:   nil,
        next_mission_body:    nil,
        has_diagnoses:        false,
        coach_message:        nil,
        daily_mission:        nil,
        singer_rank:          nil,
        singer_rank_progress: nil,
        singer_next_rank:     nil,
        singing_xp:           0
      )
    end
  end
end
