class Business::CommunitiesController < ApplicationController

  before_action :set_community, only: [:show, :edit, :update, :destroy, :permits]
  before_action only: [:new, :create] do
    require_feature!(:business_community_create, redirect_to_path: business_communities_path)
  end

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
