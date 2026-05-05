module Singing
  class AggregateSeasonRankingJob < ApplicationJob
    queue_as :default

    def perform(season_id)
      season = SingingRankingSeason.find(season_id)
      Singing::SeasonRankingAggregator.new(season).call
    end
  end
end
