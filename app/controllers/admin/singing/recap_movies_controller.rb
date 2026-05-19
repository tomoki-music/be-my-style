class Admin::Singing::RecapMoviesController < ApplicationController
  skip_before_action :authenticate_customer!
  skip_before_action :ensure_music_domain_access_for_public_routes!, raise: false
  before_action :authenticate_admin!
  before_action :set_recap_movie, only: [:show]

  def index
    @movies = SingingGeneratedRecapMovie.includes(:customer).order(created_at: :desc)

    @stats = {
      total:                     @movies.count,
      completed:                 @movies.completed.count,
      failed:                    @movies.failed.count,
      processing:                @movies.processing.count,
      pending:                   @movies.pending.count,
      expired:                   @movies.expired.count,
      total_shares:              @movies.sum(:share_count),
      total_downloads:           @movies.sum(:download_count),
      total_instagram_clicks:    @movies.sum(:instagram_hint_click_count),
    }

    @recent_movies  = @movies.limit(30)
    @failed_movies  = SingingGeneratedRecapMovie.includes(:customer).failed.order(updated_at: :desc).limit(20)
  end

  def show
  end

  private

  def set_recap_movie
    @movie = SingingGeneratedRecapMovie.includes(:customer).find(params[:id])
  end
end
