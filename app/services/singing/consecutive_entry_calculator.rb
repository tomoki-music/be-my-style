module Singing
  class ConsecutiveEntryCalculator
    Result = Struct.new(:customer, :count, keyword_init: true)

    DEFAULT_THRESHOLD = 3

    def self.call(season_id, threshold: DEFAULT_THRESHOLD)
      new(season_id, threshold: threshold).call
    end

    def initialize(season_id, threshold: DEFAULT_THRESHOLD)
      @season = SingingRankingSeason.find_by(id: season_id)
      @threshold = threshold
    end

    def call
      return [] unless season

      current_entries.filter_map do |entry|
        count = consecutive_count_for(entry.customer_id)
        next if count < threshold

        Result.new(customer: entry.customer, count: count)
      end
    end

    private

    attr_reader :season, :threshold

    def current_entries
      @current_entries ||= season.singing_season_ranking_entries
                                 .overall
                                 .includes(:customer)
    end

    def seasons_until_current
      @seasons_until_current ||= SingingRankingSeason
                                 .where("starts_on <= ?", season.starts_on)
                                 .order(starts_on: :desc, id: :desc)
    end

    def participated_season_ids_for(customer_id)
      SingingSeasonRankingEntry
        .overall
        .where(customer_id: customer_id, singing_ranking_season_id: seasons_until_current.select(:id))
        .distinct
        .pluck(:singing_ranking_season_id)
        .to_set
    end

    def consecutive_count_for(customer_id)
      participated_season_ids = participated_season_ids_for(customer_id)

      seasons_until_current.take_while do |ranking_season|
        participated_season_ids.include?(ranking_season.id)
      end.count
    end
  end
end
