class Singing::UsersController < Singing::BaseController
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
    @ranking_badges = Singing::RankingBadgeService.badges_for(@user)
    @growth_entries = Singing::RankingQuery.growth
    @growth_index = @growth_entries.index { |entry| entry.customer.id == @user.id }
    @growth_entry = @growth_index.present? ? @growth_entries[@growth_index] : nil
    @growth_position = @growth_index.present? ? @growth_index + 1 : nil
    @safe_profile_url = safe_external_url(@user.url)
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
end
