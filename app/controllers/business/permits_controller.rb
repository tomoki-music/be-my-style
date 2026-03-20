class Business::PermitsController < ApplicationController

  before_action :set_community

  def create
    Permit.create!(
      community_id: @community.id,
      customer_id: current_customer.id
    )

    redirect_after_action
  end

  def destroy
    permit = Permit.find_by(
      community_id: @community.id,
      customer_id: current_customer.id
    )

    permit&.destroy

    redirect_after_action
  end

  private

  def set_community
    @community = Community.find_by!(
      id: params[:community_id],
      domain_id: @current_domain.id
    )
  end

  def redirect_after_action
    if current_customer.onboarding_done?
      redirect_to business_community_path(@community)
    else
      redirect_to onboarding_step2_path
    end
  end

end