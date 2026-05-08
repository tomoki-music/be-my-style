class Singing::SeasonHistoriesController < Singing::BaseController
  SeasonHistoryEntry = Struct.new(:season, :entry, :growth_entry, :badges, :diagnosis_count, keyword_init: true) do
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

    def growth_rank
      growth_entry&.rank
    end

    def growth_score
      growth_entry&.score
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

    my_growth_entries = SingingSeasonRankingEntry
                          .where(
                            customer_id: current_customer.id,
                            singing_ranking_season_id: season_ids,
                            category: "growth"
                          )
                          .index_by(&:singing_ranking_season_id)

    my_badges = SingingBadge
                  .where(
                    customer_id: current_customer.id,
                    singing_ranking_season_id: season_ids
                  )
                  .group_by(&:singing_ranking_season_id)

    diagnosis_counts = build_diagnosis_counts(seasons)

    @season_histories = seasons.map do |season|
      SeasonHistoryEntry.new(
        season:         season,
        entry:          my_entries[season.id],
        growth_entry:   my_growth_entries[season.id],
        badges:         my_badges[season.id] || [],
        diagnosis_count: diagnosis_counts[season.id] || 0
      )
    end
  end

  private

  def build_diagnosis_counts(seasons)
    return {} if seasons.empty?

    min_date = seasons.last.starts_on.beginning_of_day
    max_date = seasons.first.ends_on.end_of_day

    diagnosed_ats = SingingDiagnosis
                      .where(customer_id: current_customer.id, status: :completed)
                      .where(diagnosed_at: min_date..max_date)
                      .pluck(:diagnosed_at)

    seasons.each_with_object({}) do |season, h|
      start_dt = season.starts_on.beginning_of_day
      end_dt   = season.ends_on.end_of_day
      h[season.id] = diagnosed_ats.count { |dt| dt >= start_dt && dt <= end_dt }
    end
  end
end
