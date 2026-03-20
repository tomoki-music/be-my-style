class Business::RelationshipsController < ApplicationController
  def create

    @customer = Customer.find(params[:followed_id])

    current_customer.follow(@customer.id)

  end

  def destroy

    @customer = Customer.find(params[:customer_id])

    current_customer.unfollow(@customer.id)

  end
end
