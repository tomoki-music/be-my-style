class Public::CommunityCustomersController < ApplicationController
  before_action :authenticate_customer!

  def create
    @community = Community.find(params[:community_id])
    @permit = Permit.find(params[:permit_id])
    @community_customer = CommunityCustomer.create(customer_id: @permit.customer_id, community_id: params[:community_id])
    if @community_customer.valid?
      owner = Customer.find_by(id: @community.owner_id)
      @community_customer.customer.create_notification_accept(owner)
      @permit.destroy
      flash[:notice] = "コミュニティへ参加を許可しました"
      redirect_back(fallback_location: root_path)
    else
      flash[:alert] = "参加申請の許可に失敗しました"
      redirect_back(fallback_location: root_path)
    end
  end

end
