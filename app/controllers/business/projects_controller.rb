class Business::ProjectsController < ApplicationController
  include BusinessAccessControl

  layout "business"

  THREAD_PREVIEW_LIMIT = 5

  before_action :set_project, only: [:show, :edit, :update, :destroy, :destroy_confirmation, :join, :leave, :cancel_request, :members]
  before_action -> { require_business_eligibility!(business_project_path(@project), manager: current_customer.business_project_manager?(@project)) }, only: [:show, :join]
  before_action :set_community, only: [:new, :create]
  before_action :authorize_project_creation!, only: [:new, :create]
  before_action :require_business_project_manager!, only: [:edit, :update, :members]
  before_action :require_business_project_destroyer!, only: [:destroy, :destroy_confirmation]

  # 一覧に出すのは、内部を閲覧できるコミュニティ(参加済み・運営中)の通常公開のプロジェクトだけ。
  def index
    @projects = current_customer.business_visible_projects(@current_domain).listed

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

    # プライベートを選べるのはシステム管理者と親コミュニティのオーナー本人だけ(フォームにも出さない)。
    # 権限の無い送信を通常公開に置き換えると意図より広く公開されるため、保存せずにフォームへ戻す。
    if @project.visibility_private? && !current_customer.can_manage_business_private_projects_in?(@community)
      @project.errors.add(:base, "プライベートのプロジェクトを作成できるのは、システム管理者とコミュニティのオーナーだけです。")
      return render :new
    end

    if @project.save
      # プライベートは参加者以外にプロジェクト名を知らせないため、コミュニティ参加者への作成通知を送らない。
      notify_project_created!(@project) unless @project.visibility_private?
      redirect_to business_community_path(@community), notice: "プロジェクトを作成しました"
    else
      render :new
    end
  end

  # 参加者(管理者を含む)にはスレッド・メンバーを、コミュニティ参加者には申請に必要な概要だけを見せる。
  # 管理者にも参加者と同じ画面を出し、設定変更・承認・停止は編集 / メンバー管理画面へ分ける。
  def show
    @community = @project.community
    # プライベートは find_business_project! で参加者・管理者に限っており、親コミュニティへの所属は求めない。
    unless @project.visibility_private? || current_customer.business_community_participant?(@community)
      return redirect_to business_community_path(@community), alert: "このプロジェクトに参加するには、先にコミュニティへの参加が必要です。"
    end
    # 招待先のこのプロジェクトに到達したら、招待先の記録を消す(次回以降のログインで再び転送しない)。
    BusinessSignupInvitation.where(customer_id: current_customer.id, target_type: "Project", target_id: @project.id).delete_all

    @can_view_internal = current_customer.business_project_participant?(@project)
    @can_manage_project = current_customer.business_project_manager?(@project)
    @join_status = Business::Memberships::ProjectStatuses.for(customer: current_customer, project: @project)
    return unless @can_view_internal

    @thread_repair_failed = !Business::ProjectThreads::LegacyChatBackfill.call_safely(project: @project)
    @threads = @project.project_threads.includes(customer: { profile_image_attachment: :blob }).display_order.limit(THREAD_PREVIEW_LIMIT).to_a
    @thread_count = @project.project_threads.count
    @thread_post_counts = ProjectChat.where(project_thread_id: @threads.map(&:id)).group(:project_thread_id).count
    @pending_request_count = @project.project_join_requests.count if @can_manage_project
  end

  def edit
    @community = @project.community
    @pending_request_count = @project.project_join_requests.count
  end

  # プライベートへの変更・プライベートからの変更は閲覧できる範囲が変わるため、ここでは反映しない。
  # ほかの項目だけ保存して、影響を示す確認画面(Business::ProjectVisibilitiesController)へ進める。
  def update
    @community = @project.community
    @pending_request_count = @project.project_join_requests.count
    attributes = project_params
    requested_visibility = attributes.delete(:visibility) if private_boundary?(attributes[:visibility])

    if @project.update(attributes)
      if requested_visibility
        redirect_to edit_business_project_visibility_path(@project, to: requested_visibility),
          notice: "公開範囲以外の変更を保存しました。公開範囲の変更はまだ反映されていません。内容を確認してください。"
      else
        redirect_to business_project_path(@project), notice: "更新しました！"
      end
    else
      render :edit
    end
  end

  def destroy_confirmation
    @community = @project.community
    @deletion_impact = Business::ProjectDeletionImpact.call(@project)
  end

  def destroy
    community = @project.community
    if @project.destroy
      redirect_to business_community_path(community), notice: "プロジェクト「#{@project.title}」を削除しました。"
    else
      redirect_to edit_business_project_path(@project), alert: "プロジェクトを削除できませんでした。"
    end
  end

  # 自動承認なら即参加、手動承認なら承認待ちにする(ページを開いただけでは参加しない)。
  def join
    result = Business::Memberships::JoinProject.call(project: @project, customer: current_customer, message: join_request_message)
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
    # プライベートは退出すると開けなくなる(再参加には新しい招待が必要)ため、ホームへ戻す。
    if @project.visibility_private? && !current_customer.business_project_participant?(@project)
      return redirect_to(business_root_path, notice: "プロジェクトから退出しました")
    end

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

  def join_request_message
    request_params = params[:project_join_request]
    message = request_params[:message] if request_params.is_a?(ActionController::Parameters)
    message if message.is_a?(String)
  end

  # 編集画面の削除ボタンの表示と同じ判定(Customer#can_destroy_business_project?)。
  def require_business_project_destroyer!
    return if current_customer.can_destroy_business_project?(@project)

    redirect_to business_project_path(@project), alert: "このプロジェクトを削除する権限がありません。"
  end

  def set_community
    community_id =
      params[:community_id] ||
      params.dig(:project, :community_id)

    @community = find_business_community!(community_id)
  end

  # 所属コミュニティは作成時の @community で決め、パラメータでは変更させない(他コミュニティへの移動を防ぐ)。
  # 取りやめた goal(目標)・deadline(締切)は、直接送られても受け付けない(保存済みの値はそのまま残る)。
  def project_params
    permitted = params.require(:project).permit(
      :title,
      :theme,
      :description,
      :project_image,
      :project_image_position_x,
      :project_image_position_y,
      :status,
      :join_approval_mode,
      :visibility,
      :thread_creation_policy
    )
    # 選択肢にない公開範囲は enum が例外を出すため、受け付けずに保存済みの値を残す。
    permitted.delete(:visibility) unless Project.visibilities.key?(permitted[:visibility].to_s)
    # 編集でのプライベートへの変更・プライベートからの変更は、権限のある人(システム管理者・親コミュニティのオーナー)だけ。
    # 権限の無い送信は無視して保存済みの値を残す(フォームにも出さない)。
    permitted.delete(:visibility) if action_name == "update" && private_boundary?(permitted[:visibility]) &&
                                     !current_customer.can_manage_business_project_privacy?(@project)
    permitted.delete(:thread_creation_policy) unless thread_creation_policy_changeable?(permitted[:thread_creation_policy])
    permitted
  end

  # スレッドを作成できる人は、編集画面からシステム管理者・親コミュニティのオーナー本人だけが変えられる。
  # 新規作成時と権限の無い人からの送信は無視する(既定値・保存済みの値のまま)。
  def thread_creation_policy_changeable?(value)
    action_name == "update" &&
      current_customer.can_change_project_thread_creation_policy?(@project) &&
      Project.thread_creation_policies.key?(value.to_s)
  end

  def notify_project_created!(project)
    recipients = project.community.active_customers.includes(:business_notification_setting).where.not(id: current_customer.id)
    recipients.find_each do |customer|
      customer.business_notification_project_created(current_customer, project)
      next unless customer.business_email_notifications_enabled?

      CustomerMailer.with(
        ac_customer: current_customer,
        ps_customer: customer,
        project: project
      ).business_project_created_mail.deliver_later
    end
  end

  def notify_project_joined!(project)
    Business::Memberships::NotifyProjectJoined.call(project: project, actor: current_customer)
  end

  # 保存済みの公開範囲から value へ変えると、プライベートに入る・出る(閲覧できる範囲が変わる)か。
  def private_boundary?(value)
    return false if value.blank? || value.to_s == @project.visibility

    value.to_s == "private" || @project.visibility_private?
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
