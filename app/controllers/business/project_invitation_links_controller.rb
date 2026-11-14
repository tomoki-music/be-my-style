# プライベートプロジェクトの招待リンクの発行・無効化。システム管理者と親コミュニティのオーナー本人だけ。
# リンク(トークン入り URL)は発行した直後のこの画面にだけ表示する(保存していないため、見失ったら再発行する)。
class Business::ProjectInvitationLinksController < ApplicationController
  include BusinessAccessControl

  layout "business"

  before_action :set_project
  before_action :require_privacy_manager!
  before_action :require_private_project!
  before_action :prevent_caching

  def show
    load_page
  end

  def create
    expiry_days = params[:expiry_days].to_i
    expiry_days = ProjectInvitationLink::DEFAULT_EXPIRY_DAYS unless ProjectInvitationLink::EXPIRY_DAYS.include?(expiry_days)
    _link, token = ProjectInvitationLink.issue!(project: @project, created_by: current_customer, expiry_days: expiry_days)

    # リダイレクトすると URL を次の画面へ渡す手段(セッション・クエリ)にトークンが残るため、この応答でだけ表示する。
    @issued_url = business_project_invitation_url(token: token, **Rails.application.config.x.business_share_url_options)
    flash.now[:notice] = "招待リンクを発行しました。このリンクは今だけ表示されます。コピーして招待したい人に送ってください。"
    load_page
    render :show
  end

  def destroy
    revoked = ProjectInvitationLink.revoke_all!(@project)
    notice = revoked.positive? ? "招待リンクを無効にしました。このリンクではもう参加できません。" : "有効な招待リンクはありません。"
    redirect_to business_project_invitation_link_path(@project), notice: notice
  end

  private

  def set_project
    @project = find_business_project!(params[:project_id])
  end

  def load_page
    @community = @project.community
    @pending_request_count = @project.project_join_requests.count
    @link = @project.project_invitation_links.order(created_at: :desc, id: :desc).first
    @link_status = @link&.status
  end

  def require_privacy_manager!
    return if current_customer.can_manage_business_project_privacy?(@project)

    redirect_to business_project_path(@project), alert: "招待リンクを発行・無効化できるのは、システム管理者とコミュニティのオーナーだけです。"
  end

  def require_private_project!
    return if @project.visibility_private?

    redirect_to edit_business_project_path(@project), alert: "招待リンクは、公開範囲が「プライベート」のプロジェクトで使えます。"
  end

  def prevent_caching
    response.headers["Cache-Control"] = "no-store"
  end
end
