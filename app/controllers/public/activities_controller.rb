class Public::ActivitiesController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:update, :edit, :destroy]
  before_action :set_activity, only: [:show, :edit, :update, :destroy]

  def index
    @activities = Activity.all.order(created_at: :desc).page(params[:page]).per(5)
  end

  def new
    @activity = Activity.new
  end

  def create
    @activity = Activity.new(activity_params)
    @activity.customer_id = current_customer.id
    if @activity.save
      if current_customer.chat_room_customers.present?
        community_ids = current_customer.chat_room_customers.pluck(:community_id)
        member_ids = []
        community_ids.each do |community_id|
          Community.where(id: community_id).each do |community|
            member_ids += community.customers.pluck(:id)
          end
        end
        member_ids.uniq.each do |member_id|
          if Customer.find(member_id) != current_customer
            Customer.find(member_id).create_notification_activity_for_community(current_customer, @activity.id)
            if Customer.find(member_id).confirm_mail
              CustomerMailer.with(ac_customer: current_customer, ps_customer: Customer.find(member_id), activity: @activity).create_activity_mail.deliver_later
            end
          end
        end
      elsif current_customer.followers.present?
        current_customer.followers.each do |customer|
          customer.create_notification_activity_for_follow(current_customer, @activity.id)
        end
      end
      redirect_to public_activities_path, notice: "活動報告の投稿が完了しました!"
    else
      render "new", alert: "もう一度お試しください。"
    end
  end

  def show
    @comment = Comment.new
  end

  def edit
    
  end

  def update
    if @activity.update(activity_params)
      redirect_to public_activity_path(@activity), notice: "活動報告の編集が完了しました!"
    else
      render "edit", alert: "もう一度お試しください。"
    end
  end

  def destroy
    @activity.destroy
    redirect_to public_activities_path, alert: "活動報告を削除しました!"
  end

  private

  def activity_params
    params.require(:activity).permit(
      :title,
      :introduction,
      :activity_image,
      :activity_video,
      :keep,
      :problem,
      :try,
      :url,
      :url_comment,
      :youtube_url,
    )
  end

  def ensure_correct_customer
    @activity = Activity.find(params[:id])
    unless @activity.customer == current_customer
      redirect_to public_activities_path, alert: "編集権限がありません。"
    end
  end

  def set_activity
    @activity = Activity.find(params[:id])
  end
end
