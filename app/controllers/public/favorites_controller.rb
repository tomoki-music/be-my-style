class Public::FavoritesController < ApplicationController
  
  def create
    @activity = Activity.find_by(id: params[:activity_id])
    @activity_favorite = Favorite.new(customer_id: current_customer.id, activity_id: params[:activity_id])
    @activity_favorite.save
  end

  def destroy
    @activity = Activity.find_by(id: params[:activity_id])
    @activity_favorite = Favorite.find_by(customer_id: current_customer.id, activity_id: params[:activity_id])
    @activity_favorite.destroy
  end
end
