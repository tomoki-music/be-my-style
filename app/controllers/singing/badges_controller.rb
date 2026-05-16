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
end
