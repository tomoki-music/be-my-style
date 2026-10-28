# コミュニティ運営者による参加者のアクセス停止・解除。
# 停止すると配下プロジェクトの参加資格も外れる。解除しても参加資格は戻さない(再度の参加・申請が必要)。
class Business::CommunityAccessSuspensionsController < ApplicationController
  include BusinessAccessControl

  before_action :set_community
  before_action :require_business_community_manager!

  def create
    customer = Customer.find_by(id: params[:customer_id])
    return redirect_to(business_permits_path(@community), alert: "ユーザーが見つかりません。") unless customer

    # 運営者は停止しても内部を閲覧できるため、対象外にする(運営者の変更は管理画面で行う)。
    if customer.can_manage_community?(@community)
      return redirect_to business_permits_path(@community), alert: "コミュニティの運営者はアクセス停止できません。"
    end

    Business::Memberships::RevokeCommunityAccess.call(community: @community, customer: customer, suspend: true, actor: current_customer)
    redirect_to business_permits_path(@community), notice: "#{customer.name}さんのアクセスを停止しました"
  end

  def destroy
    @community.community_access_suspensions.where(id: params[:id]).destroy_all
    redirect_to business_permits_path(@community), notice: "アクセス停止を解除しました（参加するには再度の参加・申請が必要です）"
  end

  private

  def set_community
    @community = find_business_community!(params[:community_id])
  end
end
