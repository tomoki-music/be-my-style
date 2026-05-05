class Singing::RankingsController < Singing::BaseController
  def index
    @ranking_type = params[:type].presence_in(%w[overall growth]) || "overall"
    @ranking_plan_context = build_ranking_plan_context

    case @ranking_type
    when "growth"
      @growth_rankings = Singing::RankingQuery.growth
      @my_growth_entry = @growth_rankings.find { |e| e.customer.id == current_customer.id }
      unless @my_growth_entry
        @my_completed_count = current_customer.singing_diagnoses
                                              .completed
                                              .where.not(overall_score: nil)
                                              .count
      end
    else
      @rankings = Singing::RankingQuery.overall
      @my_best_diagnosis = current_customer.singing_diagnoses
                                           .completed
                                           .where(ranking_opt_in: true)
                                           .where.not(overall_score: nil)
                                           .order(overall_score: :desc, id: :desc)
                                           .first
      @my_position = @my_best_diagnosis ? Singing::RankingQuery.position_for(current_customer.id) : nil
    end
  end

  private

  def build_ranking_plan_context
    {
      plan: current_customer.plan,
      # FUTURE: light以上で「自分の順位推移」タブ解放予定
      can_view_rank_history: current_customer.has_feature?(:singing_diagnosis_comparison),
      # FUTURE: core以上で「成長ランキング」本格参加予定
      can_join_growth_ranking: current_customer.has_feature?(:singing_diagnosis_advanced_feedback),
      # FUTURE: premiumで「シーズンランキング」「称号詳細」解放予定
      can_access_premium_features: current_customer.plan == "premium"
    }
  end
end
