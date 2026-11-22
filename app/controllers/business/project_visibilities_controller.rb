# プライベートへの変更・プライベートからの変更の確認画面。閲覧できる範囲が変わるため、影響を示してから反映する。
# 操作できるのはシステム管理者と親コミュニティのオーナー本人(BusinessAccess#can_manage_business_project_privacy?)。
# 通常公開と限定公開の切り替えは、従来どおり編集フォームでそのまま保存する。
class Business::ProjectVisibilitiesController < ApplicationController
  include BusinessAccessControl

  layout "business"

  before_action :set_project
  before_action :require_privacy_manager!
  before_action :set_target_visibility

  def edit
    @community = @project.community
    @pending_request_count = @project.project_join_requests.count
    @member_count = @project.participating_members.count
    # プライベートから戻すと、親コミュニティに参加していないメンバーは閲覧できなくなる(通常・限定公開の参加条件)。
    @members_outside_community_count =
      @project.visibility_private? ? @project.participating_members.where.not(id: @community.community_customers.select(:customer_id)).count : 0
    @active_link = @project.project_invitation_links.not_revoked.where("expires_at > ?", Time.current).exists?
  end

  def update
    unless params[:confirmed] == "1"
      return redirect_to edit_business_project_visibility_path(@project, to: @target_visibility), alert: "確認のうえ「変更する」を押してください。"
    end

    result = Business::Projects::ChangeVisibility.call(project: @project, visibility: @target_visibility)
    redirect_to business_project_path(@project), notice: change_notice(result)
  end

  private

  def set_project
    @project = find_business_project!(params[:project_id])
  end

  def require_privacy_manager!
    return if current_customer.can_manage_business_project_privacy?(@project)

    redirect_to business_project_path(@project), alert: "公開範囲をプライベートに変更する・プライベートから戻す権限がありません。"
  end

  # この画面で扱うのは、プライベートに入る・出る変更だけ。それ以外(同じ値・通常公開⇔限定公開・不正な値)は編集画面へ戻す。
  def set_target_visibility
    @target_visibility = params[:to].to_s
    crossing = Project.visibilities.key?(@target_visibility) && @target_visibility != @project.visibility &&
               (@target_visibility == "private" || @project.visibility_private?)
    return if crossing

    redirect_to edit_business_project_path(@project)
  end

  def change_notice(result)
    label = helpers.business_project_visibility_label(@project)
    return "公開範囲はすでに「#{label}」です。" unless result.changed

    notice = "公開範囲を「#{label}」に変更しました。"
    notice += "承認待ちの参加申請#{result.cancelled_request_count}件を取り消しました。" if result.cancelled_request_count.positive?
    notice += "招待リンクを無効にしました。" if result.revoked_link_count.positive?
    notice
  end
end
