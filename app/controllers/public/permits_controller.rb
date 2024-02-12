class Public::PermitsController < ApplicationController
  before_action :authenticate_customer!

  def create
    @community = Community.find(params[:community_id])
    permit = current_customer.permits.new(community_id: params[:community_id])
    if permit.save
      owner = Customer.find_by(id: @community.owner_id)
      if current_customer != owner
        owner.create_notification_request(current_customer, @community.id)
        if owner.confirm_mail
          CustomerMailer.with(ac_customer: current_customer, ps_customer: owner, community: @community).create_request_mail.deliver_later
        end
      end
      flash[:notice] = "コミュニティへ参加申請をしました"
      redirect_back(fallback_location: root_path)
    else
      flash[:alert] = "申請に失敗しました"
      redirect_back(fallback_location: root_path)
    end
  end

  def destroy
    @community = Community.find(params[:community_id])
    owner = Customer.find_by(id: @community.owner_id)
    owner.create_notification_request_cancel(current_customer, @community.id)
    permit = current_customer.permits.find_by(community_id: params[:community_id])
    permit.destroy
    flash[:alert] = "このコミュニティへの参加申請を取消しました"
    redirect_back(fallback_location: root_path)
  end
end
