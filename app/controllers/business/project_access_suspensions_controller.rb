# プロジェクト管理者による参加者のアクセス停止・解除。
# 解除しても参加資格は戻さない(再度の参加・申請が必要)。
class Business::ProjectAccessSuspensionsController < ApplicationController
  include BusinessAccessControl

  before_action :set_project
  before_action :require_business_project_manager!

  def create
    customer = Customer.find_by(id: params[:customer_id])
    return redirect_to(members_business_project_path(@project), alert: "ユーザーが見つかりません。") unless customer

    # 管理者自身や上位の運営者は停止しても内部を閲覧できるため、対象外にする。
    if customer.business_project_manager?(@project) || customer.admin?
      return redirect_to members_business_project_path(@project), alert: "プロジェクトの管理者はアクセス停止できません。"
    end

    Business::Memberships::RevokeProjectAccess.call(project: @project, customer: customer, suspend: true, actor: current_customer)
    redirect_to members_business_project_path(@project), notice: "#{customer.name}さんのアクセスを停止しました"
  end

  def destroy
    @project.project_access_suspensions.where(id: params[:id]).destroy_all
    redirect_to members_business_project_path(@project), notice: "アクセス停止を解除しました（参加するには再度の参加・申請が必要です）"
  end

  private

  def set_project
    @project = find_business_project!(params[:project_id])
  end
end
