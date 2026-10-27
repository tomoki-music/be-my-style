class Business::CommunityCustomersController < ApplicationController
  include BusinessAccessControl

  before_action :set_community

  # 参加申請の承認。詳細画面の参加申請カードと同じ権限(Customer#can_manage_community?)で、
  # 申請が出ている会員だけを参加させる。
  def create
    unless current_customer.can_manage_community?(@community)
      return redirect_to business_community_path(@community), alert: "参加申請を承認する権限がありません。"
    end

    applicant = @community.permits.find_by(customer_id: params[:customer_id])&.customer
    result = Business::Memberships::ApproveCommunityRequest.call(community: @community, customer_id: params[:customer_id])

    case result
    when :approved
      notify_accepted!(applicant)
      flash[:notice] = "コミュニティへ参加を許可しました"
    when :withdrawn
      flash[:alert] = "退会済みのユーザーです。参加を許可できません。"
    when :suspended
      flash[:alert] = "アクセス停止中のユーザーです。申請は取り消しました。"
    else
      return redirect_to business_community_path(@community), alert: "参加申請が見つかりません。"
    end

    redirect_to(params[:return_to] == "permits" ? business_permits_path(@community) : business_community_path(@community))
  end

  # 本人の退会。配下プロジェクトの参加資格も外れる(再参加しても復活しない)。
  def destroy
    Business::Memberships::RevokeCommunityAccess.call(community: @community, customer: current_customer)

    flash[:alert] = "コミュニティから退会しました"
    redirect_to business_community_path(@community)
  end

  private

  def set_community
    @community = find_business_community!(params[:community_id])
  end

  def notify_accepted!(customer)
    owner = @community.owner || current_customer
    customer.business_notification_accept(owner, @community.id)
    return unless customer.confirm_mail

    CustomerMailer.with(ac_customer: owner, ps_customer: customer, community: @community).business_accept_mail.deliver_later
  end

end