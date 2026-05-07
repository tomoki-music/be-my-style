module Singing
  class AwardSeasonBadgesJob < ApplicationJob
    queue_as :default

    def perform(season_id)
      season = SingingRankingSeason.find(season_id)
      Singing::SeasonBadgeAwarder.call(season)
    end
  end
end
