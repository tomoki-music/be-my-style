class Public::CommunityEventEditorsController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_community
  before_action :authorize_event_editor_management!

  def create
    customer = eligible_customer

    if customer.blank?
      redirect_to public_community_path(@community), alert: "対象のメンバーが見つかりません。"
      return
    end

    unless CommunityEventEditor.assignable?(customer, @community)
      redirect_to public_community_path(@community), alert: "このメンバーはすでにイベントを編集できる権限を持っています。"
      return
    end

    CommunityEventEditor.find_or_create_by!(community: @community, customer: customer)
    redirect_to public_community_path(@community), notice: "イベント編集者に設定しました。"
  end

  def destroy
    community_event_editor = @community.community_event_editors.find_by(id: params[:id])
    community_event_editor&.destroy
    redirect_to public_community_path(@community), notice: "イベント編集者を解除しました。"
  end

  private

  def set_community
    @community = Community.find_by!(id: params[:community_id], domain_id: @current_domain.id)
  end

  def authorize_event_editor_management!
    unless current_customer.admin? || current_customer.can_manage_community?(@community)
      redirect_to public_community_path(@community), alert: "イベント編集者を設定する権限がありません。"
    end
  end

  # 設定対象は原則としてこのコミュニティに所属しているメンバーに限定する
  # (CommunityCustomer / CommunityOwner / Community#owner のいずれか)。
  def eligible_customer
    customer = Customer.find_by(id: params[:customer_id])
    return nil if customer.blank?
    return nil unless community_member?(customer)

    customer
  end

  def community_member?(customer)
    return true if @community.owner_id == customer.id
    return true if @community.owners.exists?(id: customer.id)

    @community.customers.exists?(id: customer.id)
  end
end
