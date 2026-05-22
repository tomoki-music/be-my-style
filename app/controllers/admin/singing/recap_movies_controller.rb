require "csv"

class Admin::Singing::RecapMoviesController < ApplicationController
  skip_before_action :authenticate_customer!
  skip_before_action :ensure_music_domain_access_for_public_routes!, raise: false
  before_action :authenticate_admin!
  before_action :set_recap_movie, only: [:show, :regenerate]

  VALID_STATUSES = %w[pending processing completed failed expired].freeze
  PER_PAGE_DEFAULT = 30
  PER_PAGE_MAX = 100
  VALID_YEAR_RANGE = (2020..(Time.zone.today.year + 1)).freeze

  def index
    scope = build_filtered_scope

    respond_to do |format|
      format.html do
        prepare_html_vars(scope)
      end

      format.csv do
        send_data generate_csv(scope.with_attached_video_file),
                  filename: "recap_movies-#{Time.zone.today}.csv",
                  type: "text/csv; charset=utf-8"
      end
    end
  end

  def preview_yearly_batch
    year = parse_batch_year

    unless year
      redirect_to admin_singing_recap_movies_path, alert: "年の指定が不正です。"
      return
    end

    @batch_preview = Singing::RecapMovieBatchPreviewService.call(year)
    @preview_year  = year

    scope = build_filtered_scope
    prepare_html_vars(scope)
    render :index
  end

  def show
  end

  def generate_yearly_batch
    year = parse_batch_year

    unless year
      redirect_to admin_singing_recap_movies_path, alert: "年の指定が不正です。"
      return
    end

    if SingingRecapMovieBatchExecution.active_for_year(year).exists?
      redirect_to admin_singing_recap_movies_path,
                  alert: "#{year}年のRecap Movie一括生成は既に実行中です。"
      return
    end

    preview = Singing::RecapMovieBatchPreviewService.call(year)

    execution = SingingRecapMovieBatchExecution.create!(
      year:                    year,
      admin:                   current_admin,
      target_customers_count:  preview[:target_customers_count],
      new_movies_count:        preview[:new_movies_count],
      regenerate_movies_count: preview[:regenerate_movies_count],
      skipped_movies_count:    preview[:skipped_movies_count],
      skipped_breakdown:       preview[:skipped_breakdown],
      status:                  :enqueued,
      enqueued_at:             Time.current,
    )

    Singing::GenerateYearlyRecapMoviesJob.perform_later(year, execution.id)

    redirect_to admin_singing_recap_movies_path,
                notice: "#{year}年のRecap Movie一括生成を開始しました。"
  end

  def health
    @dashboard = Singing::RecapMovieHealthDashboardService.call
  end

  def regenerate
    unless @movie.failed? || @movie.expired?
      redirect_to admin_singing_recap_movie_path(@movie),
                  alert: "このRecap Movieは現在のステータスでは再生成できません。"
      return
    end

    @movie.update!(
      status:          :pending,
      error_message:   nil
    )
    Singing::GenerateRecapMovieJob.perform_later(@movie.id)

    redirect_to admin_singing_recap_movie_path(@movie),
                notice: "Recap Movieの再生成を開始しました。"
  end

  private

  def parse_batch_year
    year = Integer(params[:year], exception: false)
    return nil unless year
    return nil unless VALID_YEAR_RANGE.include?(year)

    year
  end

  def prepare_html_vars(scope)
    @stats = {
      total:                  SingingGeneratedRecapMovie.count,
      completed:              SingingGeneratedRecapMovie.completed.count,
      failed:                 SingingGeneratedRecapMovie.failed.count,
      processing:             SingingGeneratedRecapMovie.processing.count,
      pending:                SingingGeneratedRecapMovie.pending.count,
      expired:                SingingGeneratedRecapMovie.expired.count,
      total_shares:           SingingGeneratedRecapMovie.sum(:share_count),
      total_downloads:        SingingGeneratedRecapMovie.sum(:download_count),
      total_instagram_clicks: SingingGeneratedRecapMovie.sum(:instagram_hint_click_count),
    }

    per_page = (params[:per_page].to_i > 0) ? params[:per_page].to_i : PER_PAGE_DEFAULT
    per_page = [per_page, PER_PAGE_MAX].min
    @per_page = per_page

    page = [params[:page].to_i, 1].max
    @page = page

    @total_count = scope.count
    @movies = scope.offset((page - 1) * per_page).limit(per_page)
    @total_pages = (@total_count.to_f / per_page).ceil

    @failed_movies = SingingGeneratedRecapMovie.includes(:customer).failed.order(updated_at: :desc).limit(20)

    @recent_batch_executions = SingingRecapMovieBatchExecution
      .includes(:admin)
      .order(created_at: :desc)
      .limit(10)

    @active_executions = SingingRecapMovieBatchExecution
      .includes(:admin)
      .where(status: %w[enqueued running])
      .order(created_at: :desc)

    @active_batch_years = @active_executions.map(&:year).uniq

    @status_counts = VALID_STATUSES.each_with_object({}) do |s, h|
      h[s] = @stats[s.to_sym]
    end

    raw_year_counts = SingingGeneratedRecapMovie.group(:year).order(year: :desc).count
    @year_counts = raw_year_counts.each_with_object({}) do |(year, count), h|
      h[year.presence || "不明"] = count
    end
  end

  def set_recap_movie
    @movie = SingingGeneratedRecapMovie.includes(:customer).find(params[:id])
  end

  def build_filtered_scope
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

    scope
  end

  CSV_HEADERS = %w[
    id customer_id customer_name customer_email
    status year theme diagnosis_count best_score average_score top_growth_metric voice_type
    share_count download_count instagram_hint_click_count
    first_shared_at last_shared_at last_downloaded_at last_instagram_hint_clicked_at
    video_attached video_filename video_byte_size
    error_message created_at updated_at generated_at expires_at
  ].freeze

  def generate_csv(scope)
    CSV.generate(headers: true, encoding: "UTF-8") do |csv|
      csv << CSV_HEADERS

      scope.each do |movie|
        props = movie.generated_props_hash
        video = movie.video_file

        csv << [
          movie.id,
          movie.customer_id,
          movie.customer.name,
          movie.customer.email,
          movie.status,
          movie.year,
          props["theme"],
          props["diagnosisCount"],
          props["bestScore"],
          props["averageScore"],
          props["topGrowthMetric"],
          props["voiceType"],
          movie.share_count,
          movie.download_count,
          movie.instagram_hint_click_count,
          movie.first_shared_at,
          movie.last_shared_at,
          movie.last_downloaded_at,
          movie.last_instagram_hint_clicked_at,
          video.attached?,
          video.attached? ? video.filename.to_s : nil,
          video.attached? ? video.byte_size : nil,
          movie.error_message,
          movie.created_at,
          movie.updated_at,
          movie.generated_at,
          movie.expires_at,
        ]
      end
    end
  end
end
