class Business::CommunitiesController < ApplicationController

  before_action :set_community, only: [:show]

  def index
    @communities = Community.where(domain: current_domain)
  end

  def show
    @projects = @community.projects
  end

  def new
    @community = Community.new
  end

  def create
    @community = current_customer.communities.new(community_params)
    @community.domain = current_domain

    if @community.save
      redirect_to business_community_path(@community)
    else
      render :new
    end
  end

  private

  def set_community
    @community = Community.find(params[:id])
  end

  def community_params
    params.require(:community).permit(
      :name,
      :description
    )
  end

end