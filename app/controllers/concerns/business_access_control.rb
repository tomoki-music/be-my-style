# Business のコミュニティ・プロジェクト配下の画面で共通の取得・認可。
# 判定そのものは Customer(BusinessAccess)に置き、ここではリダイレクト先と文言だけを揃える。
module BusinessAccessControl
  extend ActiveSupport::Concern

  COMMUNITY_JOIN_MESSAGES = {
    joined: [:notice, "コミュニティに参加しました"],
    requested: [:notice, "コミュニティへ参加申請しました"],
    already_member: [:notice, "すでにコミュニティに参加しています"],
    already_requested: [:notice, "参加申請は承認待ちです"],
    suspended: [:alert, "このコミュニティへのアクセスは停止されています"],
    unavailable: [:alert, "このコミュニティには参加できません"]
  }.freeze

  PROJECT_JOIN_MESSAGES = {
    joined: [:notice, "プロジェクトに参加しました！"],
    requested: [:notice, "プロジェクトへ参加申請しました"],
    already_member: [:notice, "すでにプロジェクトに参加しています"],
    already_requested: [:notice, "参加申請は承認待ちです"],
    suspended: [:alert, "このプロジェクトへのアクセスは停止されています"],
    community_required: [:alert, "コミュニティへの参加が必要です"],
    closed: [:alert, "このプロジェクトは募集終了しています"],
    unavailable: [:alert, "このプロジェクトには参加できません"]
  }.freeze

  private

  def find_business_community!(id)
    Community.find_by!(id: id, domain_id: @current_domain.id)
  end

  def find_business_project!(id)
    Project.in_domain(@current_domain).find(id)
  end

  # プロジェクト内部(スレッド・投稿・メンバー)の閲覧・投稿。コミュニティ未参加者はコミュニティの申請画面へ戻す。
  def require_business_project_participant!
    return if current_customer.business_project_participant?(@project)

    if current_customer.business_community_participant?(@project.community)
      redirect_to business_project_path(@project), alert: "このプロジェクトは参加者のみ利用できます。"
    else
      redirect_to business_community_path(@project.community), alert: "このプロジェクトはコミュニティ参加者のみ閲覧できます。"
    end
  end

  def require_business_project_manager!
    return if current_customer.business_project_manager?(@project)

    redirect_to business_project_path(@project), alert: "このプロジェクトを管理する権限がありません。"
  end

  def require_business_community_manager!
    return if current_customer.can_manage_community?(@community)

    redirect_to business_community_path(@community), alert: "このコミュニティを管理する権限がありません。"
  end

  def flash_membership_result(messages, result)
    type, message = messages.fetch(result)
    flash[type] = message
  end
end
