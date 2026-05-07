module Singing
  class SeasonBadgeAwarder
    def self.call(season)
      new(season).call
    end

    def initialize(season)
      @season = season
      @now = Time.current
    end

    def call
      award_count = 0

      overall_entries.each do |entry|
        badge_types_for_rank(entry.rank).each do |badge_type|
          award_count += 1 if award(entry.customer, badge_type)
        end
      end

      award_count
    end

    private

    attr_reader :season, :now

    def overall_entries
      season.singing_season_ranking_entries
            .includes(:customer)
            .where(category: "overall")
            .order(:rank)
    end

    def badge_types_for_rank(rank)
      case rank
      when 1
        %w[monthly_champion monthly_top_3 monthly_top_10 season_participant]
      when 2
        %w[monthly_runner_up monthly_top_3 monthly_top_10 season_participant]
      when 3
        %w[monthly_top_3 monthly_top_10 season_participant]
      when 4..10
        %w[monthly_top_10 season_participant]
      else
        %w[season_participant]
      end
    end

    def award(customer, badge_type)
      badge = SingingBadge.find_or_create_by!(
        customer: customer,
        singing_ranking_season: season,
        badge_type: badge_type
      ) { |badge| badge.awarded_at = now }

      badge.previously_new_record?
    end
  end
end
