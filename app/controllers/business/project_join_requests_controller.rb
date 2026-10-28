# プロジェクト管理者による参加申請の承認・却下。却下は申請を消すだけなので、申請者は再申請できる。
class Business::ProjectJoinRequestsController < ApplicationController
  include BusinessAccessControl

  before_action :set_project
  before_action :require_business_project_manager!

  APPROVE_MESSAGES = {
    approved: [:notice, "参加を承認しました"],
    not_found: [:alert, "参加申請が見つかりません。"],
    withdrawn: [:alert, "退会済みのユーザーです。参加を承認できません。"],
    community_required: [:alert, "申請者がコミュニティに参加していないため承認できません。申請は取り消しました。"],
    suspended: [:alert, "アクセス停止中のユーザーです。申請は取り消しました。"]
  }.freeze

  def approve
    request = @project.project_join_requests.find_by(id: params[:id])
    applicant = request&.customer
    result = Business::Memberships::ApproveProjectRequest.call(project: @project, request_id: params[:id])

    if result == :approved
      applicant.business_notification_project_accept(current_customer, @project)
    end

    flash_membership_result(APPROVE_MESSAGES, result)
    redirect_to members_business_project_path(@project)
  end

  def reject
    @project.project_join_requests.where(id: params[:id]).destroy_all
    redirect_to members_business_project_path(@project), notice: "参加申請を却下しました"
  end

  private

  def set_project
    @project = find_business_project!(params[:project_id])
  end
end
