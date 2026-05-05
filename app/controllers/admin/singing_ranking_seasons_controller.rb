class Admin::SingingRankingSeasonsController < ApplicationController
  skip_before_action :authenticate_customer!
  skip_before_action :ensure_music_domain_access_for_public_routes!
  before_action :authenticate_admin!
  before_action :set_season, only: [:show, :edit, :update, :aggregate]

  def index
    @seasons = SingingRankingSeason.includes(:singing_season_ranking_entries).recent
  end

  def show
    @entries = @season.singing_season_ranking_entries
                      .includes(:customer)
                      .by_rank
  end

  def new
    @season = SingingRankingSeason.new(
      status: "draft",
      season_type: "monthly",
      starts_on: Date.current.beginning_of_month,
      ends_on: Date.current.end_of_month
    )
  end

  def create
    @season = SingingRankingSeason.new(season_params)
    if @season.save
      redirect_to admin_singing_ranking_season_path(@season), notice: "シーズンを作成しました。"
    else
      render :new
    end
  end

  def edit; end

  def update
    if @season.update(season_params)
      redirect_to admin_singing_ranking_season_path(@season), notice: "シーズンを更新しました。"
    else
      render :edit
    end
  end

  def aggregate
    Singing::AggregateSeasonRankingJob.perform_now(@season.id)
    redirect_to admin_singing_ranking_season_path(@season), notice: "シーズンランキングを再集計しました。"
  end

  private

  def set_season
    @season = SingingRankingSeason.find(params[:id])
  end

  def season_params
    params.require(:singing_ranking_season).permit(:name, :starts_on, :ends_on, :status, :season_type)
  end
end
