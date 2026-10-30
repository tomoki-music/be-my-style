class Business::PermitsController < ApplicationController
  include BusinessAccessControl

  before_action :set_community
  before_action -> { require_business_eligibility!(business_community_path(@community)) }, only: [:create]

  # 「参加する(自動承認) / 参加を申請する(手動承認)」。承認方式の判定と重複防止は JoinCommunity で行う。
  def create
    result = Business::Memberships::JoinCommunity.call(community: @community, customer: current_customer)
    notify_owner_of_request! if result == :requested

    flash_membership_result(COMMUNITY_JOIN_MESSAGES, result)
    redirect_after_action
  end

  # 本人による申請の取り消しと、運営者による他人の申請の拒否(customer_id 指定)を兼ねる。
  def destroy
    return reject_permit if rejecting_other_customer?

    permit = Permit.find_by(
      community_id: @community.id,
      customer_id: current_customer.id
    )

    permit&.destroy

    flash[:alert] = "コミュニティ参加申請をキャンセルしました"
    redirect_after_action
  end

  private

  # メンバー管理画面から拒否したときはその画面へ戻す。
  def reject_redirect_path
    params[:return_to] == "permits" ? business_permits_path(@community) : business_community_path(@community)
  end

  def rejecting_other_customer?
    params[:customer_id].present? && params[:customer_id].to_s != current_customer.id.to_s
  end

  # 拒否できるのは参加申請カードを閲覧できる人(Customer#can_manage_community?)だけ。
  def reject_permit
    unless current_customer.can_manage_community?(@community)
      return redirect_to business_community_path(@community), alert: "参加申請を拒否する権限がありません。"
    end

    @community.permits.find_by(customer_id: params[:customer_id])&.destroy

    redirect_to reject_redirect_path, alert: "参加申請を拒否しました"
  end

  def set_community
    @community = find_business_community!(params[:community_id])
  end

  def notify_owner_of_request!
    owner = @community.owner
    return if owner.blank? || owner.is_deleted?

    owner.business_notification_request(current_customer, @community.id)
    return unless owner.confirm_mail

    CustomerMailer.with(ac_customer: current_customer, ps_customer: owner, community: @community).business_request_mail.deliver_later
  end

  def redirect_after_action
    if current_customer.onboarding_done?
      redirect_to business_community_path(@community)
    else
      redirect_to onboarding_step2_path
    end
  end

end