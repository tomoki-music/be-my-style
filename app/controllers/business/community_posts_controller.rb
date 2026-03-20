class Business::CommunityPostsController < ApplicationController
  def create
    @community = Community.find(params[:community_id])

    post = CommunityPost.new(post_params)
    post.customer = current_customer
    post.community = @community

    if post.save
      redirect_to business_community_path(@community), notice: "投稿しました"
    else
      redirect_to business_community_path(@community), alert: "投稿失敗"
    end
  end


  private

  def post_params
    params.require(:community_post).permit(
      :body
    )
  end
end
