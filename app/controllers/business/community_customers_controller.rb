class Business::CommunityCustomersController < ApplicationController
  def create
    CommunityCustomer.create!(
      community_id: community.id,
      customer_id: permit.customer_id
    )

    permit.destroy
  end
end
