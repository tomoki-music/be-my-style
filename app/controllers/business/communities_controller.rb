class Business::CommunitiesController < ApplicationController

  before_action :set_community, only: [:show, :edit, :update, :destroy, :permits]

  def index
    @communities = Community
      .where(domain_id: @current_domain.id)
      .page(params[:page]).per(5)
  end

  def show
    @permit = Permit.find_by(
      community: @community,
      customer: current_customer
    )

    @projects = @community.projects
    @permit = @community.permits.find_by(customer: current_customer)
    @permits = @community.permits if @community.owner == current_customer
  end

  def new
    @community = Community.new
  end

  def create
    @community = Community.new(community_params)
    @community.owner = current_customer
    @community.domain_id = @current_domain.id

    if @community.save
      CommunityCustomer.create!(
        community: @community,
        customer: current_customer
      )
      redirect_to business_community_path(@community)
    else
      Rails.logger.error "🔥 SAVE FAILED"
      Rails.logger.error @community.errors.full_messages
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

  def permits
    @permits = @community.permits
  end
  
  private

  def set_community
    @community = Community.find_by!(
      id: params[:id],
      domain_id: @current_domain.id
    )
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