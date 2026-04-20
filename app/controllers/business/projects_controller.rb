class Business::ProjectsController < ApplicationController

  before_action :set_project, only: [:show, :edit, :update, :join, :leave]
  before_action :set_community, only: [:new, :create, :edit, :update]
  before_action :authorize_project_creation!, only: [:new, :create]

  def index
    if params[:community_id]
      @community = Community.find(params[:community_id])
      @projects = @community.projects
    else
      @projects = Project.all
    end
  end

  def new
    @community = Community.find(params[:community_id])
    @project = Project.new
  end

  def create
    @project = @community.projects.build(project_params)
    @project.customer = current_customer

    if @project.save
      notify_project_created!(@project)
      redirect_to business_community_path(@community)
    else
      render :new
    end
  end

  def show
    @community = @project.community
    @messages = @project.project_chats.includes(:customer).order(created_at: :asc)
    @new_message = ProjectChat.new
  end

  def edit
  end

  def update
    if @project.update(project_params)
      redirect_to business_project_path(@project), notice: "更新しました！"
    else
      render :edit
    end
  end

  def join
    @project = Project.find(params[:id])

    # 締切チェック
    if @project.deadline.present? && @project.deadline < Time.current
      redirect_to business_project_path(@project),
        alert: "このプロジェクトは募集終了しています"
      return
    end

    # コミュニティ未参加チェック
    unless @project.community.members.include?(current_customer)
      redirect_to business_project_path(@project),
        alert: "コミュニティへの参加が必要です"
      return
    end

    unless @project.members.include?(current_customer)
      @project.members << current_customer
      notify_project_joined!(@project)
    end

    redirect_to business_project_path(@project),
      notice: "プロジェクトに参加しました！"
  end

  def leave
    @project.project_members.find_by(customer: current_customer)&.destroy
    redirect_to business_project_path(@project)
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def set_community
    community_id =
      params[:community_id] ||
      params.dig(:project, :community_id) ||
      @project&.community_id

    @community = Community.find(community_id)
  end

  def project_params
    params.require(:project).permit(
      :title,
      :description,
      :community_id,
      :project_image,
      :status,
      :deadline,
      :goal
    )
  end

  def notify_project_created!(project)
    recipients = project.community.customers.where.not(id: current_customer.id)
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
    recipients = project_notification_recipients(project, include_members: true)

    recipients.uniq.each do |customer|
      customer.business_notification_project_joined(current_customer, project)
      next unless customer.confirm_mail

      CustomerMailer.with(
        ac_customer: current_customer,
        ps_customer: customer,
        project: project
      ).business_project_joined_mail.deliver_later
    end
  end

  def project_notification_recipients(project, include_members:)
    recipients = []
    recipients.concat(project.community.community_owners.includes(:customer).map(&:customer))
    recipients << project.community.owner if project.community.owner.present?
    recipients << project.customer
    recipients.concat(project.members.to_a) if include_members

    recipients.compact.reject { |customer| customer.id == current_customer.id }.uniq
  end

  def authorize_project_creation!
    return if current_customer.can_create_project_for?(@community)

    redirect_to business_community_path(@community), alert: "このコミュニティでプロジェクトを作成する権限がありません。"
  end

end
