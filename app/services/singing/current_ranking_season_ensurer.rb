module Singing
  class CurrentRankingSeasonEnsurer
    def initialize(date = Date.current)
      @date = date.to_date
    end

    def call
      existing_season = find_existing_season
      return { season: existing_season, created: false } if existing_season.present?

      { season: create_season, created: true }
    end

    private

    attr_reader :date

    def find_existing_season
      SingingRankingSeason.find_by(
        season_type: "monthly",
        starts_on: month_start,
        ends_on: month_end
      )
    end

    def create_season
      SingingRankingSeason.create!(
        name: "#{date.year}年#{date.month}月シーズン",
        starts_on: month_start,
        ends_on: month_end,
        status: "active",
        season_type: "monthly"
      )
    end

    def month_start
      @month_start ||= date.beginning_of_month
    end

    def month_end
      @month_end ||= date.end_of_month
    end
  end
end
