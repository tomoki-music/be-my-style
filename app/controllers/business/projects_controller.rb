class Business::ProjectsController < ApplicationController

  before_action :set_community
  before_action :set_project, only: [:show, :join, :leave]

  def new
    @project = @community.projects.new
  end

  def create
    @project = @community.projects.new(project_params)
    @project.owner = current_customer

    if @project.save
      redirect_to business_community_path(@community)
    else
      render :new
    end
  end

  def show
    @messages = @project.chats.order(created_at: :asc)
  end

  def join
    ProjectMember.create(
      project: @project,
      customer: current_customer
    )

    redirect_to business_project_path(@project)
  end

  def leave
    ProjectMember.find_by(
      project: @project,
      customer: current_customer
    )&.destroy

    redirect_to business_community_path(@community)
  end

  private

  def set_community
    @community = Community.find(params[:community_id])
  end

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(
      :title,
      :description
    )
  end

end