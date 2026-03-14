class Business::CommunityPostsController < ApplicationController
  def create

    post = CommunityPost.new(post_params)
    post.customer = current_customer

    post.save

    redirect_to business_community_path(post.community)

  end


  private

  def post_params
    params.require(:community_post).permit(
      :community_id,
      :body
    )
  end
end
