class Singing::RankingSeasonsController < Singing::BaseController
  def index
    @current_season = SingingRankingSeason.current.first
    @seasons = SingingRankingSeason.recent.where(status: %w[active closed])
  end

  def show
    @season = SingingRankingSeason.find(params[:id])
    @entries_by_category = @season.singing_season_ranking_entries
                                  .includes(:customer, :singing_diagnosis)
                                  .by_rank
                                  .group_by(&:category)
    @my_diagnosis_count = SingingDiagnosis
                            .where(customer_id: current_customer.id, status: :completed)
                            .where(diagnosed_at: @season.starts_on.beginning_of_day..@season.ends_on.end_of_day)
                            .count
  end
end
