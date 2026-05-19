class Singing::BadgesController < Singing::BaseController
  RARITY_LABELS = {
    legendary: "LEGENDARY",
    epic:      "EPIC",
    rare:      "RARE",
    common:    "COMMON"
  }.freeze

  CATEGORY_LABELS = {
    milestone: "節目",
    streak:    "連続",
    score:     "スコア",
    growth:    "成長",
    ranking:   "ランキング",
    skill:     "スキル",
    challenge: "チャレンジ",
    special:   "特別"
  }.freeze

  NEAR_COMPLETION_THRESHOLD = 0.7
  NEAR_COMPLETION_MAX       = 3

  PIN_LIMIT = SingingAchievementBadge::PIN_LIMIT

  RECAP_MOVIE_MESSAGES = {
    created_pending:    "動画生成の準備ができました。",
    reset_pending:      "動画生成を再リクエストしました。",
    already_pending:    "動画生成はすでに処理待ちです。",
    already_processing: "動画生成は現在処理中です。",
    reused_completed:   "生成済みの Recap Movie をご利用いただけます。",
    empty_source:       "今年のRecap Movieを作成できるAchievementがまだありません。"
  }.freeze

  ENQUEUE_STATUSES = %i[created_pending reset_pending].freeze

  RECAP_MOVIE_STATUS_MESSAGES = {
    "not_requested" => "まだRecap Movieは作成されていません。",
    "pending"       => "Recap Movieの生成を受け付けました。しばらくお待ちください。",
    "processing"    => "Recap Movieを生成中です。",
    "completed"     => "Recap Movieの生成が完了しました。",
    "failed"        => "Recap Movieの生成に失敗しました。",
    "expired"       => "Recap Movieの有効期限が切れています。"
  }.freeze

  RENDERER_NOT_IMPLEMENTED_ERROR = "Renderer is not implemented."
  RENDERER_PREPARING_MESSAGE     = "動画生成機能は現在準備中です。"

  def timeline
    @timeline_groups = Singing::AchievementTimelineBuilder.call(current_customer)
    @can_share_achievement = current_customer.has_feature?(:singing_achievement_badge_share_image)
    @earned_achievement_keys = current_customer.singing_achievement_badges
                                               .pluck(:badge_key).to_set
  end

  def monthly_wrapped
    month_str = params[:month].presence || Time.current.strftime("%Y-%m")
    @wrapped = Singing::MonthlyAchievementWrappedBuilder.call(current_customer, month_str)
  end

  def yearly_rewind
    year = params[:year].to_i
    year = Time.current.year if year < 2020 || year > Time.current.year + 1
    @rewind = Singing::YearlyAchievementRewindBuilder.call(current_customer, year: year)
    @year   = year
    @can_share_achievement = current_customer.has_feature?(:singing_achievement_badge_share_image)
  end

  def recap_movie_preview
    year = params[:year].to_i
    year = Time.current.year if year < 2020 || year > Time.current.year + 1
    @recap = Singing::AchievementRecapMovieBuilder.call(current_customer, year: year)
    @year  = year
  end

  def recap_movie
    year = sanitize_year(params[:year])
    recap = Singing::AchievementRecapMovieBuilder.call(current_customer, year: year)

    render json: Singing::AchievementRecapMovieSerializer.new(recap).as_json
  end

  def recap_movie_status
    year  = sanitize_year(params[:year])
    movie = current_customer.singing_generated_recap_movies.find_by(year: year)

    if movie.nil?
      render json: {
        exists:  false,
        year:    year,
        status:  "not_requested",
        message: RECAP_MOVIE_STATUS_MESSAGES["not_requested"],
        movie:   nil
      }
      return
    end

    status_message = if renderer_preparing?(movie)
      RENDERER_PREPARING_MESSAGE
    else
      RECAP_MOVIE_STATUS_MESSAGES[movie.status] || movie.status
    end

    render json: {
      exists:  true,
      year:    year,
      status:  movie.status,
      message: status_message,
      movie:   movie_status_payload(movie)
    }
  end

  def recap_movie_request
    result = Singing::RecapMovieRequestService.call(current_customer, year: sanitize_year(params[:year]))

    queued = ENQUEUE_STATUSES.include?(result.status)
    Singing::GenerateRecapMovieJob.perform_later(result.movie.id) if queued

    movie_data = if result.movie
      video_url = result.movie.video_file.attached? ? (url_for(result.movie.video_file) rescue nil) : nil
      {
        id:        result.movie.id,
        year:      result.movie.year,
        status:    result.movie.status,
        reusable:  result.movie.reusable?,
        video_url: video_url
      }
    end

    render json: {
      status:  result.status,
      message: RECAP_MOVIE_MESSAGES[result.status] || result.message,
      movie:   movie_data,
      queued:  queued
    }
  end

  def pin
    badge = current_customer.singing_achievement_badges.find(params[:id])

    if badge.pinned?
      render json: { ok: true, pinned: true, message: "すでに固定済みです" }
      return
    end

    if SingingAchievementBadge.pinned_limit_reached?(current_customer)
      render json: { ok: false, pinned: false, message: "固定できるバッジは最大#{PIN_LIMIT}件です" }, status: :unprocessable_entity
      return
    end

    badge.pin!
    render json: { ok: true, pinned: true, message: "バッジを固定しました" }
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def unpin
    badge = current_customer.singing_achievement_badges.find(params[:id])
    badge.unpin!
    render json: { ok: true, pinned: false, message: "固定を解除しました" }
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def index
    # ── ランキング / シーズンバッジ（既存） ────────────────────────
    @season_badges = current_customer.singing_badges
                                     .includes(:singing_ranking_season)
                                     .order(awarded_at: :desc)
    @earned_ranking_badges = Singing::RankingBadgeService.badges_for(current_customer)
    @earned_badge_keys = @earned_ranking_badges.map { |b| b[:key] }.to_set
    @all_ranking_definitions = Singing::RankingBadgeService::BADGE_PRIORITY.map do |key|
      Singing::RankingBadgeService::BADGE_DEFINITIONS[key].merge(key: key)
    end
    @next_badges = Singing::NextBadgeService.call(current_customer)

    # ── Achievement バッジ（新規） ─────────────────────────────────
    @active_category = params[:category].presence&.to_sym
    @active_rarity   = params[:rarity].presence&.to_sym

    @earned_achievement_badges = current_customer.singing_achievement_badges
                                                  .includes(:singing_diagnosis)
                                                  .order(earned_at: :desc)
    @earned_achievement_keys = @earned_achievement_badges.map(&:badge_key).to_set

    all_defs = SingingAchievementBadge::BADGE_DEFINITIONS

    # ProgressHint を一括計算（未獲得バッジのみ）
    progress_hints = Singing::ProgressHintBuilder.call(
      current_customer,
      earned_badge_keys: @earned_achievement_keys
    ).index_by(&:badge_key)

    @next_badge_hint = Singing::NextBadgeHintAggregator.call(
      current_customer,
      earned_badge_keys: @earned_achievement_keys
    )

    @grouped_achievement_badges = SingingAchievementBadge::RARITY_ORDER.each_with_object({}) do |rarity, h|
      next if @active_rarity && rarity != @active_rarity

      entries = all_defs
        .select { |_, d| d[:rarity] == rarity }
        .select { |_, d| @active_category.nil? || d[:category] == @active_category }
        .map do |key, defn|
          earned        = @earned_achievement_badges.find { |b| b.badge_key == key.to_s }
          progress_hint = earned ? nil : progress_hints[key.to_s]
          { key: key.to_s, definition: defn, earned: earned, progress_hint: progress_hint }
        end
      h[rarity] = entries unless entries.empty?
    end

    @achievement_earned_count      = @earned_achievement_keys.size
    @achievement_total_count       = all_defs.size
    @achievement_completion_rate   = @achievement_total_count.zero? ? 0 :
                                       (@achievement_earned_count * 100 / @achievement_total_count)

    # MVP バッジに存在するカテゴリのみ（フィルタ UI 用）
    @available_categories = all_defs.values.map { |d| d[:category] }.uniq
                              .sort_by { |c| SingingAchievementBadge::CATEGORY_ORDER.index(c) || 99 }

    @can_share_achievement = current_customer.has_feature?(:singing_achievement_badge_share_image)

    # ── Near Completion UX ────────────────────────────────────
    all_near = progress_hints
      .values
      .select { |h| h.progress_ratio >= NEAR_COMPLETION_THRESHOLD }
      .sort_by { |h| -h.progress_ratio }
    @near_completion_hints      = all_near.first(NEAR_COMPLETION_MAX)
    @near_completion_more_count = [all_near.size - NEAR_COMPLETION_MAX, 0].max

    # ── Collection Header UX ─────────────────────────────────
    @achievement_rarity_counts = SingingAchievementBadge::RARITY_ORDER.each_with_object({}) do |rarity, h|
      h[rarity] = @earned_achievement_badges.count { |b| b.rarity == rarity }
    end
    @recent_earned_badges = @earned_achievement_badges.first(2)
  end

  private

  def sanitize_year(raw)
    year = raw.to_i
    year < 2020 || year > Time.current.year + 1 ? Time.current.year : year
  end

  def movie_status_payload(movie)
    preparing = renderer_preparing?(movie)
    {
      id:                 movie.id,
      year:               movie.year,
      status:             movie.status,
      reusable:           movie.reusable?,
      video_url:          recap_movie_video_url(movie),
      error_message:      preparing ? nil : movie.error_message,
      renderer_preparing: preparing,
      generated_at:       movie.generated_at,
      expires_at:         movie.expires_at
    }
  end

  def renderer_preparing?(movie)
    movie.failed? && movie.error_message == RENDERER_NOT_IMPLEMENTED_ERROR
  end

  def recap_movie_video_url(movie)
    return nil unless movie.video_file.attached?
    url_for(movie.video_file)
  rescue StandardError
    nil
  end
end
