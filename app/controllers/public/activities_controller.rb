class Public::ActivitiesController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:update, :edit]
  before_action :set_activity, only: [:show, :edit, :update]

  def index
    activities = Activity.all.page(params[:page]).per(8)
  end
  
  def new
    activity = Activity.new
  end

  def create
    @activity = Activity.new(activity_params)
    if @activity.save
      redirect_to public_customer_activities_path, notice: "活動報告の投稿が完了しました!"
    else
      render "new", alert: "もう一度お試しください。"
    end
  end

  def show
    
  end

  def edit
    
  end

  def update
    if @activity.update(activity_params)
      redirect_to public_customer_activity_path(@activity), notice: "活動報告の編集が完了しました!"
    else
      render "edit", alert: "もう一度お試しください。"
    end
  end

  def destroy
    @activity = Activity.find(params[:id])
    @activity.destroy
    redirect_to public_customer_activities_path, alert: "活動報告を削除しました!"
  end

  private

  def activity_params
    params.require(:activity).permit(:title, :introduction, :activity_image, :activity_video, :keep, :problem, :try)
  end

  def ensure_correct_customer
    @activity = Activity.find(params[:id])
    unless @activity.customer == current_customer
      redirect_to public_customer_activities_path, alert: "編集権限がありません。community_customers_controller"
    end
  end

  def set_activity
    @activity = Activity.find(params[:id])
  end
end
