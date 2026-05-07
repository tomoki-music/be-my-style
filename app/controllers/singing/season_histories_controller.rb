class Singing::SeasonHistoriesController < Singing::BaseController
  SeasonHistoryEntry = Struct.new(:season, :entry, :badges, keyword_init: true) do
    def participated?
      entry.present?
    end

    def active?
      season.status == "active"
    end

    def closed?
      season.status == "closed"
    end

    def rank
      entry&.rank
    end

    def score
      entry&.score
    end
  end

  def index
    seasons = SingingRankingSeason
                .where(status: %w[active closed])
                .order(starts_on: :desc)
    season_ids = seasons.map(&:id)

    my_entries = SingingSeasonRankingEntry
                   .where(
                     customer_id: current_customer.id,
                     singing_ranking_season_id: season_ids,
                     category: "overall"
                   )
                   .index_by(&:singing_ranking_season_id)

    my_badges = SingingBadge
                  .where(
                    customer_id: current_customer.id,
                    singing_ranking_season_id: season_ids
                  )
                  .group_by(&:singing_ranking_season_id)

    @season_histories = seasons.map do |season|
      SeasonHistoryEntry.new(
        season: season,
        entry:  my_entries[season.id],
        badges: my_badges[season.id] || []
      )
    end
  end
end
