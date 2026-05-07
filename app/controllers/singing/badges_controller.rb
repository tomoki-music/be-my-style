class Singing::BadgesController < Singing::BaseController
  def index
    @season_badges = current_customer.singing_badges
                                     .includes(:singing_ranking_season)
                                     .order(awarded_at: :desc)
    @earned_ranking_badges = Singing::RankingBadgeService.badges_for(current_customer)
    @earned_badge_keys = @earned_ranking_badges.map { |b| b[:key] }.to_set
    @all_ranking_definitions = Singing::RankingBadgeService::BADGE_PRIORITY.map do |key|
      Singing::RankingBadgeService::BADGE_DEFINITIONS[key].merge(key: key)
    end
    @next_badges = Singing::NextBadgeService.call(current_customer)
  end
end
