module Business
  module ProjectCardHelper
    # プロジェクト詳細画面のボタン(参加中 / 募集終了 / 参加 / コミュニティに参加する)と同じ判定で、
    # 一覧カードに出す参加状況を返す。[ラベル, 修飾子]
    def business_project_participation(project, joined_project_ids:, joined_community_ids:)
      return ["主催", "owner"] if project.customer_id == current_customer.id
      return ["参加中", "joined"] if joined_project_ids.include?(project.id)
      return ["募集終了", "closed"] if project.deadline.present? && project.deadline < Time.current
      return ["参加できます", "open"] if joined_community_ids.include?(project.community_id)

      ["コミュニティ参加後に参加できます", "community"]
    end
  end
end
