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
      award_ranking_badges
      award_rapid_growth_badges
      award_consecutive_participation_badges
    end

    private

    attr_reader :season, :now

    # 総合ランキング上位に順位バッジを付与
    def award_ranking_badges
      season.singing_season_ranking_entries
            .includes(:customer)
            .where(category: "overall")
            .order(:rank)
            .each do |entry|
              badge_type = overall_rank_badge_type(entry.rank)
              next unless badge_type

              award(entry.customer, badge_type)
            end
    end

    # 前シーズン比で成長幅が最大のユーザーTOP3に急成長バッジを付与
    def award_rapid_growth_badges
      previous_season = previous_closed_season
      return unless previous_season

      current_scores  = season_overall_scores(season)
      previous_scores = season_overall_scores(previous_season)

      growths = current_scores.filter_map do |customer_id, score|
        prev = previous_scores[customer_id]
        next unless prev

        growth = score - prev
        [customer_id, growth] if growth.positive?
      end.to_h

      top3_ids = growths.sort_by { |_, g| -g }.first(3).map(&:first)
      Customer.where(id: top3_ids).each { |customer| award(customer, "rapid_growth") }
    end

    # 前シーズンにも参加したユーザー全員に継続バッジを付与
    def award_consecutive_participation_badges
      previous_season = previous_closed_season
      return unless previous_season

      previous_ids = previous_season.singing_season_ranking_entries.distinct.pluck(:customer_id)
      return if previous_ids.empty?

      current_ids = season.singing_season_ranking_entries.distinct.pluck(:customer_id)
      consecutive_ids = current_ids & previous_ids

      Customer.where(id: consecutive_ids).each { |customer| award(customer, "consecutive_participation") }
    end

    def overall_rank_badge_type(rank)
      case rank
      when 1 then "season_1st"
      when 2 then "season_2nd"
      when 3 then "season_top3"
      when 4..10 then "season_top10"
      end
    end

    def season_overall_scores(target_season)
      target_season.singing_season_ranking_entries
                   .where(category: "overall")
                   .index_by(&:customer_id)
                   .transform_values(&:score)
    end

    def previous_closed_season
      SingingRankingSeason
        .closed
        .where(ends_on: ...season.starts_on)
        .order(ends_on: :desc)
        .first
    end

    def award(customer, badge_type)
      SingingBadge.find_or_create_by!(
        customer: customer,
        singing_ranking_season: season,
        badge_type: badge_type
      ) { |badge| badge.awarded_at = now }
    end
  end
end
