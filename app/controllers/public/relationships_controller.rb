class Public::RelationshipsController < ApplicationController
  def create
    follow_customer_id = params[:customer_id]
    @customer = Customer.find(params[:customer_id])
    #フォロー機能
    current_customer.follow(follow_customer_id)
    if current_customer != @customer
      @customer.create_notification_follow(current_customer)
      if @customer.confirm_mail
        CustomerMailer.with(ac_customer: current_customer, ps_customer: @customer).create_follow_mail.deliver_later
      end
    end
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
