class Admin::Singing::RecapMoviesController < ApplicationController
  skip_before_action :authenticate_customer!
  skip_before_action :ensure_music_domain_access_for_public_routes!, raise: false
  before_action :authenticate_admin!
  before_action :set_recap_movie, only: [:show]

  VALID_STATUSES = %w[pending processing completed failed expired].freeze
  PER_PAGE_DEFAULT = 30
  PER_PAGE_MAX = 100

  def index
    @stats = {
      total:                     SingingGeneratedRecapMovie.count,
      completed:                 SingingGeneratedRecapMovie.completed.count,
      failed:                    SingingGeneratedRecapMovie.failed.count,
      processing:                SingingGeneratedRecapMovie.processing.count,
      pending:                   SingingGeneratedRecapMovie.pending.count,
      expired:                   SingingGeneratedRecapMovie.expired.count,
      total_shares:              SingingGeneratedRecapMovie.sum(:share_count),
      total_downloads:           SingingGeneratedRecapMovie.sum(:download_count),
      total_instagram_clicks:    SingingGeneratedRecapMovie.sum(:instagram_hint_click_count),
    }

    scope = SingingGeneratedRecapMovie.includes(:customer).order(created_at: :desc)

    if params[:status].present? && VALID_STATUSES.include?(params[:status])
      scope = scope.where(status: params[:status])
      @filter_status = params[:status]
    end

    if params[:year].present?
      year_int = Integer(params[:year], exception: false)
      if year_int
        scope = scope.where(year: year_int)
        @filter_year = year_int
      end
    end

    per_page = (params[:per_page].to_i > 0) ? params[:per_page].to_i : PER_PAGE_DEFAULT
    per_page = [per_page, PER_PAGE_MAX].min
    @per_page = per_page

    page = [params[:page].to_i, 1].max
    @page = page

    @total_count = scope.count
    @movies = scope.offset((page - 1) * per_page).limit(per_page)
    @total_pages = (@total_count.to_f / per_page).ceil

    @failed_movies = SingingGeneratedRecapMovie.includes(:customer).failed.order(updated_at: :desc).limit(20)
  end

  def show
  end

  private

  def set_recap_movie
    @movie = SingingGeneratedRecapMovie.includes(:customer).find(params[:id])
  end
end
