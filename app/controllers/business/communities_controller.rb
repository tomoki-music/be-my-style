class Business::CommunitiesController < ApplicationController
  include BusinessAccessControl

  layout "business"

  before_action :set_community, only: [:show, :edit, :update, :destroy, :permits]
  before_action :ensure_community_manager!, only: [:edit, :update, :permits]
  before_action :ensure_community_owner!, only: [:destroy]
  before_action :load_pending_permit_count, only: [:edit, :update]
  before_action only: [:new, :create] do
    require_feature!(:business_community_create, redirect_to_path: business_communities_path)
  end

  def index
    @communities = Community
      .where(domain_id: @current_domain.id)
      .with_attached_community_image
      .page(params[:page]).per(5)
  end

  # 未参加者には参加申請に必要な名称・紹介だけを見せ、プロジェクト・タイムライン・メンバーは参加者(運営者を含む)に限る。
  # 運営者にも参加者と同じ画面を出し、承認・停止・設定変更はメンバー管理 / 編集画面へ分ける。
  def show
    @can_view_internal = current_customer.business_community_participant?(@community)
    @join_status = community_join_status

    @can_manage = current_customer.can_manage_community?(@community)
    @can_create_project = current_customer.can_create_project_for?(@community)
    load_pending_permit_count if @can_manage
    return unless @can_view_internal

    @projects = @community.projects.with_attached_project_image.recently_updated
    @timeline_posts = @community.community_posts.includes(customer: { profile_image_attachment: :blob }).with_attached_attachments.order(created_at: :desc)
  end

  def new
    @community = Community.new
  end

  def create
    @community = Community.new(community_params)
    @community.owner = current_customer
    @community.domain_id = @current_domain.id
    @community.required_plan_for_event_creation = "premium"

    begin
      ActiveRecord::Base.transaction do
        @community.save!
        Rails.logger.error "✅ community saved: #{@community.id}"

        CommunityCustomer.create!(
          community_id: @community.id,
          customer_id: current_customer.id
        )
        Rails.logger.error "✅ community_customer created"
      end

      redirect_to business_community_path(@community)

    rescue => e
      Rails.logger.error "🔥🔥🔥 ERROR 🔥🔥🔥"
      Rails.logger.error e.class.name
      Rails.logger.error e.message
      Rails.logger.error e.backtrace.join("\n")
      Rails.logger.error "🔥🔥🔥 END 🔥🔥🔥"

      render :new
    end
  end

  def edit
  end

  def update
    if @community.update(community_params)
      redirect_to business_community_path(@community), notice: "更新しました"
    else
      render :edit
    end
  end

  def destroy
    @community.destroy
    redirect_to business_communities_path
  end

  # メンバー管理: 参加申請の承認・却下、参加者のアクセス停止・解除。
  def permits
    @permits = pending_permits
    @members = @community.active_customers.includes(profile_image_attachment: :blob).order("community_customers.created_at")
    @suspensions = @community.community_access_suspensions.includes(customer: { profile_image_attachment: :blob }).order(:created_at)
    # 停止ボタンを出さない運営者(can_manage_community? と同じ範囲)を1回の問い合わせで求める。
    @manager_ids = (@community.community_owners.pluck(:customer_id) + [@community.owner_id]).compact.to_set
  end

  private

  def community_join_status
    return :member if current_customer.business_community_member?(@community)
    return :manager if current_customer.can_manage_community?(@community)
    return :suspended if current_customer.business_community_suspended?(@community)
    return :pending if current_customer.business_community_pending?(@community)

    :none
  end

  def load_pending_permit_count
    @pending_permit_count = pending_permits.count
  end

  def pending_permits
    @community.permits.joins(:customer).merge(Customer.active).includes(:customer).order(:created_at)
  end

  def set_community
    @community = find_business_community!(params[:id])
  end

  # 通常画面の管理メニューと同じ条件(オーナー / 管理権限 / 管理者)。
  def ensure_community_manager!
    return if current_customer.can_manage_community?(@community)

    redirect_to business_community_path(@community), alert: "このコミュニティを編集する権限がありません。"
  end

  # 削除は取り消せないため、管理権限の付与だけでは許可せずオーナー本人と管理者に限定する。
  def ensure_community_owner!
    return if current_customer.admin? || @community.owner_id == current_customer.id

    redirect_to business_community_path(@community), alert: "このコミュニティを削除する権限がありません。"
  end

  def community_params
    params.require(:community).permit(
      :name,
      :introduction,
      :prefecture_id,
      :community_image,
      :activity_stance,
      :join_approval_mode
    )
  end

end
