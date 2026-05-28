module Singing
  class HomeGrowthDashboardBuilder
    GrowthTypeCard = Struct.new(
      :type_key, :label, :icon, :description,
      :hint, :streak, :level, :diagnosis_count,
      keyword_init: true
    )

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
      :growth_type_card,
      :journey_recap,
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

      growth_type = Singing::GrowthTypeAnalyzer.call(@customer)
      hint        = Singing::GrowthEvolutionHintBuilder.call(growth_type.type_key)

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
        singing_xp:           @customer.singing_xp,
        growth_type_card:     GrowthTypeCard.new(
          type_key:        growth_type.type_key,
          label:           growth_type.label,
          icon:            growth_type.icon,
          description:     growth_type.description,
          hint:            hint.hint,
          streak:          summary.streak_days,
          level:           @customer.singer_rank&.level,
          diagnosis_count: summary.diagnosis_count
        ),
        journey_recap:        Singing::JourneyRecapBuilder.call(@customer)
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
        singing_xp:           0,
        growth_type_card:     nil,
        journey_recap:        nil
      )
    end
  end
end
