class Singing::UsersController < Singing::BaseController
  before_action :set_user
  before_action :ensure_correct_user, only: [:edit, :update]

  def show
    @recent_diagnoses = @user.singing_diagnoses.completed.order(created_at: :desc).limit(5)
    @growth_diagnoses = @user.singing_diagnoses.completed.where.not(overall_score: nil).order(created_at: :asc).limit(12)
    @recent_activities = @user.activities.with_attached_activity_image.includes(:activity_reactions).order(created_at: :desc).limit(3)
    @activity_count = @user.activities.count
    @best_diagnosis = @user.singing_diagnoses.completed.where(ranking_opt_in: true).where.not(overall_score: nil).order(overall_score: :desc, id: :desc).first
    @ranking_position = ranking_position_for(@best_diagnosis)
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

  def ranking_position_for(best_diagnosis)
    return nil if best_diagnosis.blank?

    rankings = SingingDiagnosis
      .completed
      .where(ranking_opt_in: true)
      .where.not(overall_score: nil)
      .order(overall_score: :desc, id: :desc)
      .each_with_object([]) do |diagnosis, result|
        next if result.any? { |entry| entry.customer_id == diagnosis.customer_id }

        result << diagnosis
      end

    rankings.index { |diagnosis| diagnosis.customer_id == best_diagnosis.customer_id }&.+(1)
  end

  def safe_external_url(url)
    uri = URI.parse(url.to_s)
    return uri.to_s if uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    nil
  end
end
