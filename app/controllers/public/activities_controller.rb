class Public::ActivitiesController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:update, :edit, :destroy]
  before_action :set_activity, only: [:show, :edit, :update, :destroy]
  before_action only: [:new, :create] do
    unless onboarding_activity_exception?(:music)
      require_feature!(:music_activity_create, redirect_to_path: public_activities_path)
    end
  end

  def index
    activities = Activity.with_attached_activity_image.includes({ customer: :subscription }, :activity_reactions).left_joins(:favorites)

    if params[:keyword].present?
      keyword = "%#{params[:keyword].strip}%"
      activities = activities.where(
        "activities.title LIKE :keyword OR activities.keep LIKE :keyword OR "\
        "activities.problem LIKE :keyword OR activities.try LIKE :keyword OR "\
        "activities.introduction LIKE :keyword OR activities.url_comment LIKE :keyword",
        keyword: keyword
      )
    end

    if params[:author].present?
      author = "%#{params[:author].strip}%"
      activities = activities.joins(:customer).where("customers.name LIKE ?", author)
    end

    activities =
      case params[:sort]
      when "popular"
        activities.group("activities.id").order(Arel.sql("COUNT(favorites.id) DESC"), Arel.sql("activities.created_at DESC"))
      else
        activities.group("activities.id").order("activities.created_at DESC")
      end

    @activities = activities.page(params[:page]).per(5)

    customer_ids = @activities.map(&:customer_id).uniq
    @customer_activity_counts = Activity.where(customer_id: customer_ids).group(:customer_id).count

    @featured_activities = Activity
      .with_attached_activity_image
      .includes({ customer: :subscription }, :activity_reactions)
      .joins(customer: :subscription)
      .where(subscriptions: { plan: %w[light core premium], status: "active" })
      .where("activities.created_at >= ?", 14.days.ago)
      .order("activities.created_at DESC")
      .limit(3)
  end

  def new
    @activity = Activity.new
  end

  def create
    @activity = Activity.new(activity_params)
    @activity.customer_id = current_customer.id

    if @activity.save

      # =========================
      # 通知処理
      # =========================
      if current_customer.communities.present?
        community_ids = current_customer.communities.pluck(:id)
        member_ids = []

        community_ids.each do |community_id|
          Community.where(id: community_id).each do |community|
            member_ids += community.customers.pluck(:id)
          end
        end

        member_ids.uniq.each do |member_id|
          customer = Customer.find(member_id)
          next if customer == current_customer

          customer.create_notification_activity_for_community(current_customer, @activity.id)

          if customer.confirm_mail
            CustomerMailer.with(
              ac_customer: current_customer,
              ps_customer: customer,
              activity: @activity
            ).create_activity_mail.deliver_later
          end
        end

      elsif current_customer.followers.present?
        current_customer.followers.each do |customer|
          customer.create_notification_activity_for_follow(current_customer, @activity.id)
        end
      end

      # =========================
      #  リダイレクト分岐
      # =========================
      complete_onboarding_if_pending!

      if current_customer.onboarding_done?
        redirect_to public_activities_path, notice: "活動報告の投稿が完了しました!"
      else
        redirect_to onboarding_step3_path
      end

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
    @activity = Activity.includes(:activity_reactions).find(params[:id])
  end
end
