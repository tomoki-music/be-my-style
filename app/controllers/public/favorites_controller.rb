class Public::FavoritesController < ApplicationController
  
  def create
    @activity_favorite = Favorite.new(customer_id: current_customer.id, activity_id: params[:activity_id])
    @activity_favorite.save
    redirect_to public_activity_path(params[:activity_id])
  end

  def destroy
    @activity_favorite = Favorite.find_by(customer_id: current_customer.id, activity_id: params[:activity_id])
    @activity_favorite.destroy
    redirect_to public_activity_path(params[:activity_id])
    
  end
end
