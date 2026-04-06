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

    ActiveRecord::Base.transaction do
      @community.save!
      CommunityCustomer.create!(
        community_id: @community.id,
        customer_id: current_customer.id
      )
    end

    Rails.logger.debug "✅ community created: #{@community.id}, domain: #{@community.domain_id}"

    redirect_to business_community_path(@community)

  rescue => e
    Rails.logger.error "🔥 ERROR: #{e.message}"
    render :new
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