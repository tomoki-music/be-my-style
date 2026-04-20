class Admin::ActivitiesController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_activity, only: [:show, :edit, :update, :destroy]

  def index
    @activities = Activity.includes(:customer).order(created_at: :desc)
  end

  def show
  end

  def new
    @activity = Activity.new
  end

  def create
    @activity = Activity.new(activity_params)

    if @activity.save
      redirect_to admin_activity_path(@activity), notice: "活動報告を登録しました。"
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @activity.update(activity_params)
      redirect_to admin_activity_path(@activity), notice: "活動報告を更新しました。"
    else
      render :edit
    end
  end

  def destroy
    @activity.destroy
    redirect_to admin_activities_path, alert: "活動報告を削除しました。"
  end

  private

  def set_activity
    @activity = Activity.find(params[:id])
  end

  def activity_params
    params.require(:activity).permit(
      :customer_id,
      :title,
      :introduction,
      :activity_image,
      :activity_video,
      :keep,
      :problem,
      :try,
      :url,
      :url_comment,
      :youtube_url
    )
  end
end
