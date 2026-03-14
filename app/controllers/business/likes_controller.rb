class Business::LikesController < ApplicationController
  def create
    @post = Post.find(params[:post_id])
    current_customer.likes.create(post: @post)
    @post.create_notification_like!(current_customer)
  end

  def destroy
    @post = Post.find(params[:post_id])
    like = current_customer.likes.find_by(post: @post)
    like.destroy if like
  end
end
