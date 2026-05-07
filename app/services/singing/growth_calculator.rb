module Singing
  class GrowthCalculator
    Result = Struct.new(:customer, :score, :previous_score, :growth_amount, keyword_init: true)

    DEFAULT_LIMIT = 5

    def self.call(season_id, limit: DEFAULT_LIMIT)
      new(season_id, limit: limit).call
    end

    def initialize(season_id, limit: DEFAULT_LIMIT)
      @season = SingingRankingSeason.find_by(id: season_id)
      @limit = limit
    end

    def call
      return [] unless season && previous_season

      current_entries.filter_map do |entry|
        previous_entry = previous_entries_by_customer_id[entry.customer_id]
        next unless previous_entry

        Result.new(
          customer: entry.customer,
          score: entry.score,
          previous_score: previous_entry.score,
          growth_amount: entry.score - previous_entry.score
        )
      end.sort_by { |result| [-result.growth_amount, -result.score, result.customer.id] }.first(limit)
    end

    private

    attr_reader :season, :limit

    def previous_season
      @previous_season ||= SingingRankingSeason
                           .where("starts_on < ?", season.starts_on)
                           .order(starts_on: :desc, id: :desc)
                           .first
    end

    def current_entries
      @current_entries ||= season.singing_season_ranking_entries
                                 .overall
                                 .includes(:customer)
    end

    def previous_entries_by_customer_id
      @previous_entries_by_customer_id ||= previous_season
                                           .singing_season_ranking_entries
                                           .overall
                                           .index_by(&:customer_id)
    end
  end
end
