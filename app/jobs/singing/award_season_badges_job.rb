module Singing
  class AwardSeasonBadgesJob < ApplicationJob
    queue_as :default

    def perform(season_id)
      season = SingingRankingSeason.find_by(id: season_id)
      unless season
        Rails.logger.warn("[Singing::AwardSeasonBadgesJob] season not found: #{season_id}")
        return
      end

      award_count = Singing::SeasonBadgeAwarder.call(season)
      Rails.logger.info(
        "[Singing::AwardSeasonBadgesJob] awarded #{award_count} badges for season_id=#{season.id}"
      )
    end
  end
end
