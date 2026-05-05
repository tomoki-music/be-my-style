class Singing::RankingsController < Singing::BaseController
  def index
    @ranking_type = params[:type].presence_in(%w[overall growth season]) || "overall"
    @ranking_plan_context = build_ranking_plan_context

    case @ranking_type
    when "growth"
      @growth_rankings = Singing::RankingQuery.growth
      ranking_customers = @growth_rankings.map(&:customer)
      @my_growth_entry = @growth_rankings.find { |e| e.customer.id == current_customer.id }
      unless @my_growth_entry
        @my_completed_count = current_customer.singing_diagnoses
                                              .completed
                                              .where.not(overall_score: nil)
                                              .count
      end
    when "season"
      @season_range = Singing::RankingQuery.current_season_range
      @season_rankings = Singing::RankingQuery.season
      ranking_customers = @season_rankings.map(&:customer)
      @my_season_diagnosis = current_customer.singing_diagnoses
                                             .completed
                                             .where(ranking_opt_in: true)
                                             .where.not(overall_score: nil)
                                             .where.not(diagnosed_at: nil)
                                             .where(diagnosed_at: @season_range)
                                             .order(overall_score: :desc, diagnosed_at: :desc)
                                             .first
      @my_season_position = @my_season_diagnosis ? Singing::RankingQuery.season_position_for(current_customer.id) : nil
      unless @my_season_diagnosis
        @my_season_has_diagnosis_this_month = current_customer.singing_diagnoses
                                                              .completed
                                                              .where(diagnosed_at: @season_range)
                                                              .exists?
      end
    else
      @rankings = Singing::RankingQuery.overall
      ranking_customers = @rankings.map(&:customer)
      @my_best_diagnosis = current_customer.singing_diagnoses
                                           .completed
                                           .where(ranking_opt_in: true)
                                           .where.not(overall_score: nil)
                                           .order(overall_score: :desc, id: :desc)
                                           .first
      @my_position = @my_best_diagnosis ? Singing::RankingQuery.position_for(current_customer.id) : nil
    end

    badge_customers = Array(ranking_customers) + [current_customer]
    @badges_map = Singing::RankingBadgeService.badges_for_bulk(badge_customers)
    @my_badges = @badges_map[current_customer.id] || []
  end

  private

  def build_ranking_plan_context
    {
      plan: current_customer.plan,
      # FUTURE: light以上で「自分の順位推移」タブ解放予定
      can_view_rank_history: current_customer.has_feature?(:singing_diagnosis_comparison),
      # FUTURE: core以上で「成長ランキング」本格参加予定
      can_join_growth_ranking: current_customer.has_feature?(:singing_diagnosis_advanced_feedback),
      # FUTURE: light以上でシーズンランキング参加予定
      can_join_season_ranking: current_customer.has_feature?(:singing_diagnosis_comparison),
      # FUTURE: core以上でシーズン称号対象予定
      can_access_season_badges: current_customer.has_feature?(:singing_diagnosis_advanced_feedback),
      # FUTURE: premiumで詳細推移・特別バッジ解放予定
      can_access_premium_features: current_customer.plan == "premium"
    }
  end
end
