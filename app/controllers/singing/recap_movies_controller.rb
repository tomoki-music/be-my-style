class Singing::RecapMoviesController < Singing::BaseController
  before_action :authenticate_customer!
  before_action :set_recap_movie, only: [:show, :track_share, :request_regeneration, :generate_share_link, :update_share_visibility]

  SCORE_GROWTH_LABELS = {
    overall_score:    "総合力",
    pitch_score:      "音程",
    rhythm_score:     "リズム",
    expression_score: "表現力"
  }.freeze

  def index
    @recap_movies = current_customer.singing_generated_recap_movies.order(year: :desc)
    @eligibility  = Singing::RecapMovieCreationEligibilityService.call(current_customer)
  end

  def request_generation
    eligibility = Singing::RecapMovieCreationEligibilityService.call(current_customer)

    unless eligibility.eligible?
      redirect_to singing_recap_movies_path, alert: eligibility.message
      return
    end

    result = Singing::RecapMovieRequestService.call(current_customer, year: eligibility.year)

    case result.status
    when :created_pending, :reset_pending
      redirect_to singing_recap_movies_path,
                  notice: "#{eligibility.year}年のRecap Movie作成をリクエストしました。数分後に完成します。"
    when :reused_completed
      redirect_to singing_recap_movie_path(result.movie),
                  notice: "作成済みのRecap Movieを確認できます。"
    when :already_pending, :already_processing
      redirect_to singing_recap_movies_path,
                  notice: "すでに生成処理中です。しばらくお待ちください。"
    when :empty_source
      redirect_to singing_recap_movies_path,
                  alert: "生成に必要な診断データが見つかりません。診断を追加してからお試しください。"
    else
      redirect_to singing_recap_movies_path, notice: "処理を開始しました。"
    end
  end

  def show
    @movie_props = build_movie_props(@recap_movie)
  end

  def request_regeneration
    unless @recap_movie.expired?
      redirect_to singing_recap_movie_path(@recap_movie),
                  alert: "このRecap Movieは期限切れではないため再生成できません。"
      return
    end

    result = Singing::RecapMovieRequestService.call(current_customer, year: @recap_movie.year)

    case result.status
    when :reset_pending
      redirect_to singing_recap_movie_path(result.movie),
                  notice: "Recap Movie の再生成リクエストを受け付けました。数分後に完成します。"
    when :already_pending, :already_processing
      redirect_to singing_recap_movie_path(@recap_movie),
                  notice: "すでに再生成処理中です。しばらくお待ちください。"
    when :empty_source
      redirect_to singing_recap_movie_path(@recap_movie),
                  alert: "生成に必要なデータが見つかりません。診断を追加してからお試しください。"
    else
      redirect_to singing_recap_movie_path(@recap_movie),
                  notice: "処理を開始しました。"
    end
  end

  def generate_share_link
    unless @recap_movie.shareable?
      render json: { error: "この Recap Movie は共有できません" }, status: :unprocessable_entity
      return
    end

    token = @recap_movie.generate_share_token!
    share_url = singing_public_recap_movie_share_url(share_token: token)
    render json: { share_url: share_url }, status: :ok
  end

  def update_share_visibility
    unless @recap_movie.shareable?
      render json: { error: "この Recap Movie は変更できません" }, status: :unprocessable_entity
      return
    end

    enabled = ActiveModel::Type::Boolean.new.cast(params[:share_enabled])
    @recap_movie.update!(share_enabled: enabled)
    render json: { share_enabled: @recap_movie.share_enabled }, status: :ok
  end

  def track_share
    now = Time.current

    case params[:kind]
    when "x"
      @recap_movie.share_count += 1
      @recap_movie.first_shared_at ||= now
      @recap_movie.last_shared_at = now
    when "download"
      @recap_movie.download_count += 1
      @recap_movie.last_downloaded_at = now
    when "instagram"
      @recap_movie.instagram_hint_click_count += 1
      @recap_movie.last_instagram_hint_clicked_at = now
    else
      render json: { error: "unknown kind" }, status: :bad_request
      return
    end

    @recap_movie.save!
    Singing::AwardRecapMovieBadgesService.call(@recap_movie, params[:kind])
    render json: { ok: true }, status: :ok
  end

  private

  def set_recap_movie
    @recap_movie = current_customer.singing_generated_recap_movies.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to singing_recap_movies_path, alert: "Recap Movieが見つかりません。"
  end

  def build_movie_props(movie)
    customer   = movie.customer
    year       = movie.year
    year_range = Time.zone.local(year).all_year

    diagnoses = customer.singing_diagnoses
      .completed
      .where(created_at: year_range)
      .order(:created_at, :id)
      .to_a

    scored = diagnoses.select { |d| d.overall_score.present? }

    {
      user_name:         customer.name.to_s,
      diagnosis_count:   diagnoses.size,
      best_score:        scored.map(&:overall_score).max,
      average_score:     scored.empty? ? nil : (scored.sum(&:overall_score) / scored.size.to_f).round,
      top_growth_metric: recap_top_growth_metric(diagnoses),
      voice_type:        recap_voice_type_label(scored.last)
    }
  rescue => e
    Rails.logger.warn("[RecapMovies#show] build_movie_props error: #{e.message}")
    { user_name: movie.customer.name.to_s, diagnosis_count: nil, best_score: nil,
      average_score: nil, top_growth_metric: nil, voice_type: nil }
  end

  def recap_top_growth_metric(diagnoses)
    return nil if diagnoses.size < 2

    SCORE_GROWTH_LABELS.filter_map do |attr, label|
      values = diagnoses.filter_map { |d| d.public_send(attr) }
      next if values.size < 2

      [label, values.last.to_i - values.first.to_i]
    end.max_by { |_, delta| delta }&.first
  end

  def recap_voice_type_label(diagnosis)
    return nil unless diagnosis

    result = SingingDiagnoses::VoiceTypeAnalyzer.call(diagnosis)
    SingingDiagnoses::VoiceTypeAnalyzer::VOICE_TYPE_LABELS[result[:main_type]]
  rescue
    nil
  end
end
