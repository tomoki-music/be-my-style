class Public::CommentsController < ApplicationController
  before_action :authenticate_customer!
  before_action :ensure_correct_customer, only: [:destroy]

  def create
    @activity = Activity.find(params[:activity_id])
    @comment = Comment.new(comment_params)
    @comment.customer_id = current_customer.id
    @comment.activity_id = @activity.id
    if @comment.save
      if current_customer != @activity.customer
        @activity.customer.create_notification_comment(current_customer, @activity.id)
      end
      flash.now[:notice] = 'コメントを投稿しました'
    else
      redirect_back(fallback_location: root_path)
    end
  end

  def destroy
    @comment = Comment.find_by(id: params[:id], activity_id: params[:activity_id])
    if @comment.destroy
      @activity = Activity.find(params[:activity_id])
      flash.now[:alert] = '投稿を削除しました'
    else
      redirect_back(fallback_location: root_path)
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:comment)
  end

  def ensure_correct_customer
    comment = Comment.find_by(id: params[:id], activity_id: params[:activity_id])
    customer = comment.customer
    unless customer == current_customer
      flash[:alert] = "コメント投稿者のみ削除できます"
      redirect_back(fallback_location: root_path)
    end
  end
end
