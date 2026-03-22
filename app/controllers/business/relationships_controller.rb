# app/controllers/business/relationships_controller.rb
class Business::RelationshipsController < ApplicationController
  before_action :authenticate_customer!

  def create
    customer = Customer.find(params[:customer_id])
    current_customer.follow(customer.id)
    customer.business_notification_follow(current_customer)

    if current_customer != @customer
      if customer.confirm_mail
        CustomerMailer.with(ac_customer: current_customer, ps_customer: customer).create_follow_mail.deliver_later
      end
    end

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }
      format.js
    end
  end

  def destroy
    customer = Customer.find(params[:customer_id])
    current_customer.unfollow(customer.id)

    respond_to do |format|
      format.html { redirect_back fallback_location: root_path }
      format.js
    end
  end
end