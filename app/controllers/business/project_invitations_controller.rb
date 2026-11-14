# プライベートプロジェクトの招待リンクを開いた人の受け入れ画面。ログイン前からも開ける。
#
#   1. /business/project_invitation?token=... で開く → トークンを照合し、このブラウザのセッションにリンク ID だけを持って
#      トークンの無い /business/project_invitation へ移る(アドレスバー・履歴・以降のログにトークンを残さない)。
#   2. 未ログインなら、ログイン / 新規登録へ案内する(戻り先はこの画面。新規登録では SignupInvitations::Remember が
#      リンクを会員に記録し、確認メールを別のブラウザで開いてもオンボーディング完了時に参加を成立させる)。
#   3. ログイン後は「参加する」で受け入れ(AcceptProjectInvitation)、プロジェクトへ進む。
#
# 通常の詳細 URL だけでは参加できない(プライベートの詳細は参加者以外 404)。
class Business::ProjectInvitationsController < ApplicationController
  include BusinessAccessControl
  include BusinessReturnPath

  skip_before_action :authenticate_customer!, only: [:show]
  before_action :prevent_caching

  layout -> { customer_signed_in? ? "business" : "application" }

  UNAVAILABLE_MESSAGES = {
    not_found: "招待リンクが見つかりません。URLが正しくないか、プロジェクトが削除された可能性があります。",
    revoked: "この招待リンクは無効になっています（無効化されたか、新しいリンクが発行されました）。招待した方に新しい招待リンクを依頼してください。",
    expired: "この招待リンクは有効期限が切れています。招待した方に新しい招待リンクを依頼してください。",
    unavailable: "この招待リンクは使えなくなりました（プロジェクトが招待制ではなくなりました）。招待した方にお問い合わせください。"
  }.freeze

  ACCEPT_MESSAGES = {
    joined: [:notice, "プロジェクトに参加しました！"],
    already_member: [:notice, "すでにこのプロジェクトに参加しています"],
    suspended: [:alert, "このプロジェクトへのアクセスは停止されているため、参加できません。"],
    unavailable: [:alert, "このアカウントでは参加できません。"]
  }.freeze

  def show
    return open_with_token if params.key?(:token)

    @link = current_invitation_link
    return render_unavailable(:not_found) unless @link

    status = @link.status
    return render_unavailable(status) unless status == :active

    @project = @link.project
    return render(:sign_in_required) unless customer_signed_in?

    if current_customer.business_project_participant?(@project)
      forget_invitation_link
      return redirect_to(business_project_path(@project), notice: ACCEPT_MESSAGES.fetch(:already_member).last)
    end
    require_business_eligibility!(business_project_invitation_path)
    return if performed?

    @suspended = current_customer.business_project_suspended?(@project) || current_customer.business_community_suspended?(@project.community)
  end

  def accept
    link = current_invitation_link
    return render_unavailable(:not_found) unless link

    result = Business::Memberships::AcceptProjectInvitation.call(link: link, customer: current_customer)
    case result
    when :invalid
      render_unavailable(link.status)
    when :business_required
      require_business_eligibility!(business_project_invitation_path)
    when :joined, :already_member
      forget_invitation_link
      BusinessSignupInvitation.where(customer_id: current_customer.id, project_invitation_link_id: link.id).delete_all
      flash_membership_result(ACCEPT_MESSAGES, result)
      redirect_to business_project_path(link.project)
    else
      flash_membership_result(ACCEPT_MESSAGES, result)
      redirect_to business_project_invitation_path
    end
  end

  private

  # トークンは照合にだけ使い、セッション・ログ・画面に残さない(ログでは filter_parameters の :token で伏せられる)。
  def open_with_token
    link = ProjectInvitationLink.find_by_token(params[:token])
    forget_invitation_link
    return render_unavailable(:not_found) unless link

    session[PROJECT_INVITATION_SESSION_KEY] = link.id
    # ログイン・新規登録の後にこの画面へ戻す(Devise の戻り先。登録時は Remember がリンクを会員に記録する)。
    store_location_for(:customer, business_project_invitation_path) unless customer_signed_in?
    redirect_to business_project_invitation_path
  end

  def current_invitation_link
    id = session[PROJECT_INVITATION_SESSION_KEY]
    id.present? ? ProjectInvitationLink.includes(project: :community).find_by(id: id) : nil
  end

  def forget_invitation_link
    session.delete(PROJECT_INVITATION_SESSION_KEY)
  end

  def render_unavailable(status)
    forget_invitation_link
    @unavailable_message = UNAVAILABLE_MESSAGES.fetch(status, UNAVAILABLE_MESSAGES[:not_found])
    render :unavailable, status: (status == :not_found ? :not_found : :gone)
  end

  def prevent_caching
    response.headers["Cache-Control"] = "no-store"
  end
end
