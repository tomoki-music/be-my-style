# ログイン後ホームのカード表示。状態は Homes::MyCommunities / Homes::MyProjects が返す記号に対応する。
module MemberHomeHelper
  COMMUNITY_STATUS_LABELS = {
    manager: "運営",
    member: "参加中",
    pending: "承認待ち"
  }.freeze

  PROJECT_STATUS_LABELS = {
    manager: "管理",
    owner: "主催",
    member: "参加中",
    pending: "承認待ち"
  }.freeze

  def member_home_community_status_label(status)
    COMMUNITY_STATUS_LABELS.fetch(status)
  end

  def member_home_project_status_label(status)
    PROJECT_STATUS_LABELS.fetch(status)
  end

  def member_home_community_kind(community)
    community.business_domain? ? ["Business", "business"] : ["音楽", "music"]
  end

  def member_home_community_path(community)
    community.business_domain? ? business_community_path(community) : public_community_path(community)
  end

  # 「参加先を探す」導線。各ドメインの一覧画面に入れる人にだけ出す。
  def member_home_community_search_links
    links = []
    links << ["音楽コミュニティを探す", public_communities_path] if current_customer.admin? || current_customer.music_user?
    links << ["Businessコミュニティを探す", business_communities_path] if current_customer.admin? || current_customer.business_user?
    links
  end

  def member_home_project_search_available?
    current_customer.admin? || current_customer.business_user?
  end
end
