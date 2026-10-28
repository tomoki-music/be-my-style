# Business(NAKAMA)のコミュニティ・プロジェクトのアクセス判定。画面・コントローラ・添付配信・通知の宛先は
# すべてここを通し、ボタンの出し分けとサーバー側の認可が同じ条件になるようにする。
#
#   コミュニティ内部(プロジェクト・タイムライン・メンバー) : 承認済みの参加者 or 運営者(can_manage_community?)
#   プロジェクト内部(スレッド・投稿・添付・メンバー)       : 運営者 / プロジェクト管理者 /
#                                                          コミュニティ参加者かつプロジェクトの承認済み参加者
#   プロジェクト管理者 : コミュニティ運営者 + コミュニティ参加資格のあるプロジェクト作成者
#
# 「承認済み」は community_customers / project_members の行があること。承認待ちは permits /
# project_join_requests、アクセス停止は *_access_suspensions に分けて持つ。
module BusinessAccess
  extend ActiveSupport::Concern

  # Business コミュニティのタイムライン投稿・閲覧など、参加者向け機能を使えるか。
  def business_community_participant?(community)
    return false if community.blank? || !community.business_domain?
    return true if can_manage_community?(community)

    business_community_member?(community)
  end

  def business_community_member?(community)
    community.present? && community_customers.exists?(community_id: community.id)
  end

  def business_community_suspended?(community)
    community.present? && community_access_suspensions.exists?(community_id: community.id)
  end

  def business_community_pending?(community)
    community.present? && permits.exists?(community_id: community.id)
  end

  def business_project_manager?(project)
    community = project&.community
    return false if community.blank? || !community.business_domain?
    return true if can_manage_community?(community)

    project.customer_id == id && business_community_member?(community)
  end

  def business_project_participant?(project)
    return false if project.blank?
    return true if business_project_manager?(project)

    business_community_member?(project.community) && project_members.exists?(project_id: project.id)
  end

  def business_project_pending?(project)
    project.present? && project_join_requests.exists?(project_id: project.id)
  end

  def business_project_suspended?(project)
    project.present? && project_access_suspensions.exists?(project_id: project.id)
  end

  # 名称・紹介を見せてよいプロジェクト(一覧・件数・トップ)。内部を閲覧できるコミュニティのものに限る。
  def business_visible_projects(domain)
    projects = Project.in_domain(domain)
    return projects if admin?

    community_ids = community_customers.select(:community_id)
    projects.where(community_id: community_ids).or(projects.where(community_id: manageable_communities.select(:id)))
  end

  def can_edit_project_thread?(thread)
    return false unless business_project_participant?(thread.project)

    thread.customer_id == id || business_project_manager?(thread.project)
  end

  # スレッドの削除は(ほかの参加者の会話も消えるため)作成者であっても管理者に限る。
  # 「全体トーク」は旧導線・移行時の投稿の送り先なので削除できない(タイトル・説明は編集できる)。
  def can_destroy_project_thread?(thread)
    !thread.general? && business_project_manager?(thread.project)
  end
end
