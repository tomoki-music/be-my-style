class Business::CommunitiesController < ApplicationController

  before_action :set_community, only: [:show, :edit, :update, :destroy]

  def index
    @communities = Community
                .joins(:domains)
                .where(domains: { id: current_domain.id })
  end


  def show
    # @projects = @community.projects
    @projects = []
  end


  def new
    @community = Community.new
  end

  def create

    @community = Community.new(community_params)

    @community.owner = current_customer
    @community.domain_id = current_domain.id   # ←これが必要

    if @community.save

      CommunityDomain.create!(
        community_id: @community.id,
        domain_id: current_domain.id
      )

      CommunityCustomer.create!(
        community_id: @community.id,
        customer_id: current_customer.id
      )

      redirect_to business_community_path(@community)

    else
      render :new
    end

  end


  def edit
  end


  def update

    if @community.update(community_params)

      redirect_to business_community_path(@community)

    else
      render :edit

    end

  end


  def destroy

    @community.destroy

    redirect_to business_communities_path

  end

  def permits

    @community = Community.find(params[:id])
    @permits = @community.permits

  end
  
  private


  def set_community
    @community = Community.find(params[:id])
  end


  def community_params
    params.require(:community).permit(
      :name,
      :introduction,
      :prefecture_id,
      :community_image,
      :activity_stance
    )
  end

end