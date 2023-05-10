class Public::RelationshipsController < ApplicationController
  def create
    follow_customer_id = params[:customer_id]
    @customer = Customer.find(params[:customer_id])

    current_customer.follow(follow_customer_id)
    @customer.create_notification_follow(current_customer)
    
    redirect_to request.referer
  end
  def destroy
    current_customer.unfollow(params[:customer_id])
    redirect_to request.referer
  end
  def followings
    customer = Customer.find(params[:customer_id])
    @customers = customer.followings
  end
  def followers
    customer = Customer.find(params[:customer_id])
    @customers = customer.followers
  end
end
