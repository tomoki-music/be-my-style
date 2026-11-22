class Public::PermitsController < ApplicationController
  before_action :authenticate_customer!

  def create
    @community = Community.find(params[:community_id])
    result = request_join!

    case result
    when :requested
      notify_owner_of_request!
      flash[:notice] = "コミュニティへ参加申請をしました"
    when :already_requested
      flash[:notice] = "このコミュニティへは参加申請済みです。承認をお待ちください"
    when :already_member
      flash[:notice] = "このコミュニティにはすでに参加しています"
    else
      flash[:alert] = "申請に失敗しました"
    end
    redirect_back(fallback_location: root_path)
  end

  # 取り消し済みの申請をもう一度取り消しても(画面の再送など)、エラーにせず通知も増やさない。
  def destroy
    @community = Community.find(params[:community_id])
    permit = current_customer.permits.find_by(community_id: @community.id)
    if permit
      permit.destroy
      owner = Customer.find_by(id: @community.owner_id)
      owner.create_notification_request_cancel(current_customer, @community.id) if owner && owner != current_customer
    end
    flash[:alert] = "このコミュニティへの参加申請を取消しました"
    redirect_back(fallback_location: root_path)
  end

  private

  # 連打・再送で同じ申請を重ねない(承認待ち一覧に同じ人が並び、通知も増えるため)。
  def request_join!
    @community.with_lock do
      next :already_member if CommunityCustomer.exists?(community_id: @community.id, customer_id: current_customer.id)
      next :already_requested if current_customer.permits.exists?(community_id: @community.id)

      current_customer.permits.create(community_id: @community.id).persisted? ? :requested : :failed
    end
  end

  def notify_owner_of_request!
    owner = Customer.find_by(id: @community.owner_id)
    return if owner.blank? || owner == current_customer

    owner.create_notification_request(current_customer, @community.id)
    return unless owner.confirm_mail

    CustomerMailer.with(ac_customer: current_customer, ps_customer: owner, community: @community).create_request_mail.deliver_later
  end
end
