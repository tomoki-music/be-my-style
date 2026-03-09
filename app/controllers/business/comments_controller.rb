class Business::CommentsController < ApplicationController
  def create
    post = Post.find(params[:post_id])
    comment = current_customer.comments.new(comment_params)
    comment.post_id = post.id

    comment.save

    redirect_to business_post_path(post)
  end

  def destroy
    comment = Comment.find(params[:id])
    comment.destroy

    redirect_back(fallback_location: business_posts_path)
  end

  private

  def comment_params
    params.require(:comment).permit(:body)
  end
end
