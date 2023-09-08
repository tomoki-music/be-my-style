class Public::FavoritesController < ApplicationController
  
  def create
    @activity = Activity.find_by(id: params[:activity_id])
    @activity_favorite = Favorite.new(customer_id: current_customer.id, activity_id: params[:activity_id])
    if @activity_favorite.save
      @activity.customer.create_notification_favorite(current_customer, @activity.id)
    end
  end

  def destroy
    @activity = Activity.find_by(id: params[:activity_id])
    @activity_favorite = Favorite.find_by(customer_id: current_customer.id, activity_id: params[:activity_id])
    @activity_favorite.destroy
  end
end
