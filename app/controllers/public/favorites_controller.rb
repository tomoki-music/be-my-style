class Public::FavoritesController < ApplicationController
  before_action :authenticate_customer!
  
  def create
    @activity = Activity.find_by(id: params[:activity_id])
    @activity_favorite = Favorite.new(customer_id: current_customer.id, activity_id: params[:activity_id])
    if @activity_favorite.save
      if current_customer != @activity.customer
        @activity.customer.create_notification_favorite(current_customer, @activity.id)
        if @activity.customer.confirm_mail
          CustomerMailer.with(ac_customer: current_customer, ps_customer: @activity.customer, activity: @activity).create_favorite_mail.deliver_later
        end
      end
    end
  end

  def destroy
    @activity = Activity.find_by(id: params[:activity_id])
    @activity_favorite = Favorite.find_by(customer_id: current_customer.id, activity_id: params[:activity_id])
    @activity_favorite.destroy
  end
end
