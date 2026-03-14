class Business::MessagesController < ApplicationController
  def create
    @post = Post.find(params[:post_id])
    @message = @post.messages.new(message_params)
    @message.customer_id = current_customer.id
    
    if @message.save
      @post.create_notification_message!(
        current_customer,
      )

      respond_to do |format|
        format.html { redirect_to business_post_path(@post) }
        format.js
      end

    else
      # 失敗した場合、元の詳細画面に戻す
      @messages = @post.messages
      render "business/posts/show"
    end
  end

  private

  def message_params
    params.require(:message).permit(:body)
  end
end
