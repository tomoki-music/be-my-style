class Business::LikesController < ApplicationController
  def create
    @post = Post.find(params[:post_id])
    current_customer.likes.create(post: @post)
    @post.create_notification_like!(current_customer)

    if @post.customer.confirm_mail
      CustomerMailer.with(
        ac_customer: current_customer,
        ps_customer: @post.customer,
        post: @post
      ).like_post_mail.deliver_later
    end
  end

  def destroy
    @post = Post.find(params[:post_id])
    like = current_customer.likes.find_by(post: @post)
    like.destroy if like
  end
end
