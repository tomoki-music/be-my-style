class Business::CommunityPostsController < ApplicationController
  include BusinessChatSubmission

  before_action :set_community
  before_action :ensure_participant!
  before_action only: [:create] do
    require_feature!(:business_community_post_create, community: @community, redirect_to_path: business_community_path(@community))
  end

  def create
    attributes = business_chat_attributes(:community_post)
    return redirect_to(business_community_path(@community), alert: business_chat_too_many_files_message) if attributes.nil?

    post = CommunityPost.new(attributes)
    post.customer = current_customer
    post.community = @community

    if post.save
      redirect_to business_community_path(@community), notice: "投稿しました"
    else
      redirect_to business_community_path(@community), alert: business_chat_error_message(post)
    end
  end

  private

  def set_community
    @community = Community.find_by!(
      id: params[:community_id],
      domain_id: @current_domain.id
    )
  end

  def ensure_participant!
    return if current_customer.business_community_participant?(@community)

    redirect_to business_community_path(@community), alert: "コミュニティに参加すると投稿できます。"
  end
end
