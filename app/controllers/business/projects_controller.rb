class Business::ProjectsController < ApplicationController
  include BusinessAccessControl

  layout "business"

  THREAD_PREVIEW_LIMIT = 5

  before_action :set_project, only: [:show, :edit, :update, :join, :leave, :cancel_request, :members]
  before_action :set_community, only: [:new, :create]
  before_action :authorize_project_creation!, only: [:new, :create]
  before_action :require_business_project_manager!, only: [:edit, :update, :members]

  # 一覧に出すのは、内部を閲覧できるコミュニティ(参加済み・運営中)のプロジェクトだけ。
  def index
    @projects = current_customer.business_visible_projects(@current_domain)

    if params[:community_id]
      @community = find_business_community!(params[:community_id])
      return redirect_to(business_community_path(@community), alert: "プロジェクトはコミュニティ参加者のみ閲覧できます。") unless current_customer.business_community_participant?(@community)

      @projects = @projects.where(community_id: @community.id)
    end

    @projects = @projects.includes(:community, :customer, project_image_attachment: :blob).recently_updated.to_a
    @join_statuses = Business::Memberships::ProjectStatuses.call(customer: current_customer, projects: @projects)
  end

  def new
    @project = Project.new
  end

  def create
    @project = @community.projects.build(project_params)
    @project.customer = current_customer

    if @project.save
      notify_project_created!(@project)
      redirect_to business_community_path(@community), notice: "プロジェクトを作成しました"
    else
      render :new
    end
  end

  # 参加者(管理者を含む)にはスレッド・メンバーを、コミュニティ参加者には申請に必要な概要だけを見せる。
  # 管理者にも参加者と同じ画面を出し、設定変更・承認・停止は編集 / メンバー管理画面へ分ける。
  def show
    @community = @project.community
    unless current_customer.business_community_participant?(@community)
      return redirect_to business_community_path(@community), alert: "このプロジェクトに参加するには、先にコミュニティへの参加が必要です。"
    end

    @can_view_internal = current_customer.business_project_participant?(@project)
    @can_manage_project = current_customer.business_project_manager?(@project)
    @join_status = Business::Memberships::ProjectStatuses.for(customer: current_customer, project: @project)
    return unless @can_view_internal

    @thread_repair_failed = !Business::ProjectThreads::LegacyChatBackfill.call_safely(project: @project)
    @threads = @project.project_threads.includes(customer: { profile_image_attachment: :blob }).recently_active.limit(THREAD_PREVIEW_LIMIT).to_a
    @thread_count = @project.project_threads.count
    @thread_post_counts = ProjectChat.where(project_thread_id: @threads.map(&:id)).group(:project_thread_id).count
    @pending_request_count = @project.project_join_requests.count if @can_manage_project
  end

  def edit
    @community = @project.community
    @pending_request_count = @project.project_join_requests.count
  end

  def update
    @community = @project.community
    @pending_request_count = @project.project_join_requests.count
    if @project.update(project_params)
      redirect_to business_project_path(@project), notice: "更新しました！"
    else
      render :edit
    end
  end

  # 自動承認なら即参加、手動承認なら承認待ちにする(ページを開いただけでは参加しない)。
  def join
    result = Business::Memberships::JoinProject.call(project: @project, customer: current_customer)
    case result
    when :joined then notify_project_joined!(@project)
    when :requested then notify_project_requested!(@project)
    end

    flash_membership_result(PROJECT_JOIN_MESSAGES, result)
    if result == :community_required
      redirect_to business_community_path(@project.community)
    else
      redirect_to business_project_path(@project)
    end
  end

  def leave
    Business::Memberships::RevokeProjectAccess.call(project: @project, customer: current_customer)
    redirect_to business_project_path(@project), notice: "プロジェクトから退出しました"
  end

  def cancel_request
    current_customer.project_join_requests.where(project_id: @project.id).destroy_all
    redirect_to business_project_path(@project), notice: "参加申請を取り消しました"
  end

  # 管理画面: 参加申請の承認・却下、参加者のアクセス停止・解除。
  def members
    @community = @project.community
    @join_requests = @project.project_join_requests.joins(:customer).merge(Customer.active).includes(customer: { profile_image_attachment: :blob }).order(:created_at)
    @members = @project.participating_members.includes(profile_image_attachment: :blob).order("project_members.created_at")
    @suspensions = @project.project_access_suspensions.includes(customer: { profile_image_attachment: :blob }).order(:created_at)
    # 停止ボタンを出さない管理者(business_project_manager? と同じ範囲)を1回の問い合わせで求める。
    @manager_ids = (@community.community_owners.pluck(:customer_id) + [@community.owner_id, @project.customer_id]).compact.to_set
  end

  private

  def set_project
    @project = find_business_project!(params[:id])
  end

  def set_community
    community_id =
      params[:community_id] ||
      params.dig(:project, :community_id)

    @community = find_business_community!(community_id)
  end

  # 所属コミュニティは作成時の @community で決め、パラメータでは変更させない(他コミュニティへの移動を防ぐ)。
  def project_params
    params.require(:project).permit(
      :title,
      :description,
      :project_image,
      :status,
      :deadline,
      :goal,
      :join_approval_mode
    )
  end

  def notify_project_created!(project)
    recipients = project.community.active_customers.where.not(id: current_customer.id)
    recipients.find_each do |customer|
      customer.business_notification_project_created(current_customer, project)
      next unless customer.confirm_mail

      CustomerMailer.with(
        ac_customer: current_customer,
        ps_customer: customer,
        project: project
      ).business_project_created_mail.deliver_later
    end
  end

  def notify_project_joined!(project)
    project.accessible_customers.where.not(id: current_customer.id).find_each do |customer|
      customer.business_notification_project_joined(current_customer, project)
      next unless customer.confirm_mail

      CustomerMailer.with(
        ac_customer: current_customer,
        ps_customer: customer,
        project: project
      ).business_project_joined_mail.deliver_later
    end
  end

  # 承認できる人(プロジェクト管理者)にだけ、画面内の通知で知らせる。
  def notify_project_requested!(project)
    project_manager_recipients(project).each do |customer|
      customer.business_notification_project_request(current_customer, project)
    end
  end

  def project_manager_recipients(project)
    recipients = project.community.community_owners.includes(:customer).map(&:customer)
    recipients << project.community.owner
    recipients << project.customer if project.customer&.business_community_member?(project.community)

    recipients.compact.reject { |customer| customer.id == current_customer.id || customer.is_deleted }.uniq
  end

  def authorize_project_creation!
    return if current_customer.can_create_project_for?(@community)

    redirect_to business_community_path(@community), alert: "このコミュニティでプロジェクトを作成する権限がありません。"
  end

end
