class Business::CommunityCustomersController < ApplicationController

  before_action :set_community

  # 参加申請の承認。詳細画面の参加申請カードと同じ権限(Customer#can_manage_community?)で、
  # 申請が出ている会員だけを参加させる。
  def create
    unless current_customer.can_manage_community?(@community)
      return redirect_to business_community_path(@community), alert: "参加申請を承認する権限がありません。"
    end

    permit = @community.permits.find_by(customer_id: params[:customer_id])
    unless permit
      return redirect_to business_community_path(@community), alert: "参加申請が見つかりません。"
    end

    customer = permit.customer
    owner = @community.owner

    if customer.is_deleted?
      flash[:alert] = "退会済みのユーザーです。参加を許可できません。"
      return redirect_to business_community_path(@community)
    end

    # すでに参加してたら何もしない
    unless @community.customers.include?(customer)
      CommunityCustomer.create!(
        community: @community,
        customer: customer
      )
    end

    permit.destroy

    customer.business_notification_accept(owner, @community.id)
    if customer.confirm_mail
      CustomerMailer.with(ac_customer: owner, ps_customer: customer, community: @community).business_accept_mail.deliver_later
    end

    flash[:notice] = "コミュニティへ参加を許可しました"
    redirect_to business_community_path(@community)
  end

  def destroy
    CommunityCustomer.find_by(
      community: @community,
      customer: current_customer
    )&.destroy

    flash[:alert] = "コミュニティからメンバーを外しました"
    redirect_to business_community_path(@community)
  end

  private

  def set_community
    @community = Community.find_by!(
      id: params[:community_id],
      domain_id: @current_domain.id
    )
  end

end