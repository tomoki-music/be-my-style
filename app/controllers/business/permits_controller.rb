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

  def destroy
    permit = Permit.find_by(
      community_id: @community.id,
      customer_id: current_customer.id
    )

    permit&.destroy

    flash[:alert] = "コミュニティ参加申請をキャンセルしました"
    redirect_after_action
  end

  private

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