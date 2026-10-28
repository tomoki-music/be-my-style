module Business
  module ProjectCardHelper
    # プロジェクト詳細画面のボタン(参加中 / 承認待ち / 募集終了 / 参加 / コミュニティに参加する)と同じ判定で、
    # 一覧カードに出す参加状況を返す。[ラベル, 修飾子]
    def business_project_participation(project, joined_project_ids:, joined_community_ids:, pending_project_ids: Set.new)
      return ["主催", "owner"] if project.customer_id == current_customer.id
      return ["参加中", "joined"] if joined_project_ids.include?(project.id)
      return ["承認待ち", "pending"] if pending_project_ids.include?(project.id)
      return ["募集終了", "closed"] if project.deadline_passed?
      return [project.join_auto? ? "参加できます" : "参加申請できます", "open"] if joined_community_ids.include?(project.community_id)

      ["コミュニティ参加後に参加できます", "community"]
    end
  end
end
