class Business::CommunityCustomersController < ApplicationController

  def create
    community = Community.find(params[:community_id])
    customer = Customer.find(params[:customer_id])
    owner = Customer.find(community.owner_id)

    # すでに参加してたら何もしない
    unless community.customers.include?(customer)
      CommunityCustomer.create!(
        community: community,
        customer: customer
      )
    end

    permit = Permit.find_by(
      community_id: community.id,
      customer_id: customer.id
    )
    permit&.destroy

    customer.business_notification_accept(owner, community.id)
    if customer.confirm_mail
      CustomerMailer.with(ac_customer: owner, ps_customer: customer, community: community).business_accept_mail.deliver_later
    end

    flash[:notice] = "コミュニティへ参加を許可しました"
    redirect_to business_community_path(community)
  end

  def destroy
    community = Community.find(params[:community_id])
    customer = current_customer

    CommunityCustomer.find_by(
      community: community,
      customer: customer
    )&.destroy

    flash[:alert] = "コミュニティからメンバーを外しました"
    redirect_to business_community_path(community)
  end

end