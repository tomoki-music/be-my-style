module Singing
  class EnsureCurrentRankingSeasonJob < ApplicationJob
    queue_as :default

    def perform(date = Date.current)
      result = Singing::CurrentRankingSeasonEnsurer.new(date).call
      Rails.logger.info(
        "Singing current ranking season ensured: season_id=#{result[:season].id} created=#{result[:created]}"
      )
      result
    end
  end
end
