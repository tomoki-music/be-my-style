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
  end
end
