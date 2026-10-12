class Business::PermitsController < ApplicationController

  before_action :set_community

  def create
    Permit.create!(
      community_id: @community.id,
      customer_id: current_customer.id
    )

    owner = Customer.find(@community.owner_id)
    owner.business_notification_request(current_customer, @community.id)
    if owner.confirm_mail
      CustomerMailer.with(ac_customer: current_customer, ps_customer: owner, community: @community).business_request_mail.deliver_later
    end
    flash[:notice] = "コミュニティへ参加申請しました"
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

  def rejecting_other_customer?
    params[:customer_id].present? && params[:customer_id].to_s != current_customer.id.to_s
  end

  # 拒否できるのは参加申請カードを閲覧できる人(Customer#can_manage_community?)だけ。
  def reject_permit
    unless current_customer.can_manage_community?(@community)
      return redirect_to business_community_path(@community), alert: "参加申請を拒否する権限がありません。"
    end

    @community.permits.find_by(customer_id: params[:customer_id])&.destroy

    redirect_to business_community_path(@community), alert: "参加申請を拒否しました"
  end

  def set_community
    @community = Community.find_by!(
      id: params[:community_id],
      domain_id: @current_domain.id
    )
  end

  def redirect_after_action
    if current_customer.onboarding_done?
      redirect_to business_community_path(@community)
    else
      redirect_to onboarding_step2_path
    end
  end

end