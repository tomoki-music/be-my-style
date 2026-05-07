class Singing::UsersController < Singing::BaseController
  skip_before_action :authenticate_customer!, only: [:show]
  skip_before_action :ensure_singing_access!, only: [:show]
  before_action :set_user
  before_action :ensure_correct_user, only: [:edit, :update]

  def show
    @recent_diagnoses = @user.singing_diagnoses.completed.order(created_at: :desc).limit(5)
    @growth_diagnoses = @user.singing_diagnoses.completed.where.not(overall_score: nil).order(created_at: :asc).limit(12)
    @recent_activities = @user.activities.with_attached_activity_image.includes(:activity_reactions).order(created_at: :desc).limit(3)
    @activity_count = @user.activities.count
    @best_diagnosis = @user.singing_diagnoses.completed.where(ranking_opt_in: true).where.not(overall_score: nil).order(overall_score: :desc, id: :desc).first
    @diagnosis_count = @user.singing_diagnoses.completed.where.not(overall_score: nil).count
    @ranking_position = Singing::RankingQuery.position_for(@user.id)
    @season_position = Singing::RankingQuery.season_position_for(@user.id)
    @season_achievement_entries = season_achievement_entries
    @season_badges = @user.singing_badges
                          .includes(:singing_ranking_season)
                          .order(awarded_at: :desc)
    @ranking_badges = Singing::RankingBadgeService.badges_for(@user)
    @growth_entries = Singing::RankingQuery.growth
    @growth_index = @growth_entries.index { |entry| entry.customer.id == @user.id }
    @growth_entry = @growth_index.present? ? @growth_entries[@growth_index] : nil
    @growth_position = @growth_index.present? ? @growth_index + 1 : nil
    @safe_profile_url = safe_external_url(@user.url)
    @profile_reaction_counts = @user.received_singing_profile_reactions.group(:reaction_type).count
    @current_customer_profile_reactions = if current_customer.present?
      current_customer.singing_profile_reactions.where(target_customer: @user).pluck(:reaction_type)
    else
      []
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to singing_user_path(@user), notice: "プロフィールを更新しました。"
    else
      render :edit
    end
  end

  private

  def set_user
    @user = Customer.with_attached_profile_image.includes(:parts, :genres, :subscription).find(params[:id])
  end

  def ensure_correct_user
    return if @user == current_customer

    redirect_to singing_user_path(@user), alert: "プロフィールを編集できるのは本人のみです。"
  end

  def user_params
    params.require(:customer).permit(
      :name,
      :introduction,
      :profile_image,
      :url,
      :singing_profile_comment,
      part_ids: [],
      genre_ids: []
    )
  end

  def safe_external_url(url)
    uri = URI.parse(url.to_s)
    return uri.to_s if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    nil
  end

  def season_achievement_entries
    SingingSeasonRankingEntry
      .includes(:singing_ranking_season)
      .joins(:singing_ranking_season)
      .where(customer: @user)
      .where("singing_season_ranking_entries.title IS NOT NULL OR singing_season_ranking_entries.badge_key IS NOT NULL")
      .order("singing_ranking_seasons.starts_on DESC, singing_season_ranking_entries.rank ASC, singing_season_ranking_entries.id DESC")
      .limit(5)
  end
end
