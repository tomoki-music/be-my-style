class Business::PermitsController < ApplicationController

  before_action :set_community

  def create

    Permit.create!(
      community_id: @community.id,
      customer_id: current_customer.id
    )

    redirect_to business_community_path(@community)

  end


  def destroy

    permit = Permit.find_by(
      community_id: @community.id,
      customer_id: current_customer.id
    )

    permit.destroy if permit

    redirect_to business_community_path(@community)

  end


  private

  def set_community
    @community = Community.find(params[:community_id])
  end

end