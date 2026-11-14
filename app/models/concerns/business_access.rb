# Business(NAKAMA)のコミュニティ・プロジェクトのアクセス判定。画面・コントローラ・添付配信・通知の宛先は
# すべてここを通し、ボタンの出し分けとサーバー側の認可が同じ条件になるようにする。
#
#   コミュニティ内部(プロジェクト・タイムライン・メンバー) : 承認済みの参加者 or 運営者(can_manage_community?)
#   プロジェクト内部(スレッド・投稿・添付・メンバー)       : 運営者 / プロジェクト管理者 /
#                                                          コミュニティ参加者かつプロジェクトの承認済み参加者
#   プライベートプロジェクト(詳細を含むすべて)            : 運営者 / プロジェクト管理者 / 招待で参加したメンバー
#                                                          (親コミュニティへの所属は求めない。親コミュニティで
#                                                          アクセス停止中なら閲覧できない。一覧には参加済みの本人にだけ出す)
#   プロジェクト管理者 : コミュニティ運営者 + コミュニティ参加資格のあるプロジェクト作成者
#
# 「承認済み」は community_customers / project_members の行があること。承認待ちは permits /
# project_join_requests、アクセス停止は *_access_suspensions に分けて持つ。
module BusinessAccess
  extend ActiveSupport::Concern

  # Business(NAKAMA)の利用資格。Business ドメインの登録(利用開始)が必要で、システム管理者だけは例外。
  # 音楽・歌声だけの会員は、/business/join で利用開始するまでコミュニティ・プロジェクトに参加できない。
  def business_eligible?
    admin? || business_user?
  end

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

  # 削除は取り消せないため、作成者・運営者(編集権限)では許可せず、管理者と親コミュニティのオーナー本人に限る。
  def can_destroy_business_project?(project)
    community = project&.community
    return false if community.blank? || !community.business_domain?

    can_destroy_community?(community)
  end

  def business_project_participant?(project)
    return false if project.blank?
    return true if business_project_manager?(project)

    business_project_membership_qualified?(project) && project_members.exists?(project_id: project.id)
  end

  # プロジェクトメンバーの行が有効になる条件(Project#qualified_project_members と同じ)。
  # 通常・限定公開は親コミュニティの承認済み参加者であること。プライベートは招待で参加するため親コミュニティへの
  # 所属を求めず(コミュニティの会話・ほかのプロジェクトは見えないまま)、親コミュニティでアクセス停止中でないことだけを求める。
  def business_project_membership_qualified?(project)
    community = project&.community
    return false if community.blank?
    return community.business_domain? && !business_community_suspended?(community) if project.visibility_private?

    business_community_member?(community)
  end

  # プライベートへの変更・プライベートからの変更と、招待リンクの発行・無効化をできる人。
  # 閲覧できる範囲を決める操作なので、システム管理者と親コミュニティのオーナー本人に限る(運営者・作成者は不可)。
  def can_manage_business_project_privacy?(project)
    can_manage_business_private_projects_in?(project&.community)
  end

  # 新規作成で「プライベート」を選べるか(作成前なので親コミュニティで判定する)。
  def can_manage_business_private_projects_in?(community)
    return false if community.blank? || !community.business_domain?

    can_destroy_community?(community)
  end

  def business_project_pending?(project)
    project.present? && project_join_requests.exists?(project_id: project.id)
  end

  def business_project_suspended?(project)
    project.present? && project_access_suspensions.exists?(project_id: project.id)
  end

  # スレッド投稿の通知を受け取る「参加者」。内部を閲覧できる人(business_project_participant?)のうち、
  # 承認済みの参加者と主催(コミュニティ参加資格のある作成者)に限る。運営者・システム管理者でも、
  # 参加していなければ管理権限だけでは届かない。退会済み・アクセス停止中は、行が残っていても除く。
  def business_project_notification_recipient?(project)
    return false if is_deleted? || project.blank?
    return false unless business_project_participant?(project)
    return false if business_project_suspended?(project) || business_community_suspended?(project.community)

    project.customer_id == id || project_members.exists?(project_id: project.id)
  end

  # 名称・紹介を見せてよいプロジェクト(一覧・件数・トップ)。内部を閲覧できるコミュニティのものに限る。
  def business_visible_projects(domain)
    projects = Project.in_domain(domain)
    return projects if admin?

    community_ids = community_customers.select(:community_id)
    projects.where(community_id: community_ids).or(projects.where(community_id: manageable_communities.select(:id)))
  end

  # 一覧(プロジェクト一覧)に出すプロジェクト。内部を閲覧できるコミュニティの通常公開に加え、
  # 本人が参加済みのプライベート(親コミュニティに所属していなくても)を出す。
  def business_listed_projects(domain)
    projects = Project.in_domain(domain)
    projects.where(id: business_visible_projects(domain).listed.select(:id))
      .or(projects.private_joined_by(self))
  end

  # スレッド作成の設定(Project#thread_creation_policy)を変えられる人。削除と同じく、
  # システム管理者と親コミュニティのオーナー本人に限る(運営者・プロジェクト作成者は編集できても変えられない)。
  def can_change_project_thread_creation_policy?(project)
    community = project&.community
    return false if community.blank? || !community.business_domain?

    can_destroy_community?(community)
  end

  # 新しいスレッドを作れるか。作成ボタンの表示・作成フォーム・作成処理はすべてこれを使う。
  #   owners_only : システム管理者・親コミュニティのオーナー本人
  #   managers    : + プロジェクトの運営者(business_project_manager?)
  #   all_members : + 参加承認済みのプロジェクトメンバー(承認待ち・アクセス停止中は除く)
  def can_create_project_thread?(project)
    return false if project.blank? || is_deleted?
    return false unless business_project_participant?(project)
    return true if can_change_project_thread_creation_policy?(project)

    if project.thread_creation_managers?
      business_project_manager?(project)
    elsif project.thread_creation_all_members?
      business_project_manager?(project) || business_project_approved_member?(project)
    else
      false
    end
  end

  # 参加が承認済みのプロジェクトメンバー(コミュニティ参加者でもある)。アクセス停止の記録があれば行が残っていても除く。
  def business_project_approved_member?(project)
    return false if project.blank?
    return false if business_project_suspended?(project) || business_community_suspended?(project.community)

    business_project_membership_qualified?(project) && project_members.exists?(project_id: project.id)
  end

  def can_edit_project_thread?(thread)
    return false unless business_project_participant?(thread.project)

    thread.customer_id == id || business_project_manager?(thread.project)
  end

  # スレッドの固定・解除。プロジェクト全体の見え方を変えるため、システム管理者と親コミュニティのオーナー本人に限る。
  def can_pin_project_thread?(thread)
    return false if thread.blank? || is_deleted?
    return false unless business_project_participant?(thread.project)

    can_change_project_thread_creation_policy?(thread.project)
  end

  # スレッドの削除は(ほかの参加者の会話も消えるため)作成者であっても管理者に限る。
  # 「全体トーク」は旧導線・移行時の投稿の送り先なので削除できない(タイトル・説明は編集できる)。
  def can_destroy_project_thread?(thread)
    !thread.general? && business_project_manager?(thread.project)
  end
end
