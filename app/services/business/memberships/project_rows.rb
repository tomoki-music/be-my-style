module Business
  module Memberships
    # コミュニティの参加資格が無くなった(または新たに参加し直す)会員の、配下プロジェクトでの
    # 参加済み・承認待ちを消す。再参加しても過去のプロジェクト参加資格が復活しないようにするため。
    # プロジェクトのアクセス停止は残す(停止は運営判断のため、再参加で解除しない)。
    module ProjectRows
      def self.clear!(community:, customer:)
        project_ids = community.projects.select(:id)
        ProjectMember.where(customer_id: customer.id, project_id: project_ids).destroy_all
        ProjectJoinRequest.where(customer_id: customer.id, project_id: project_ids).destroy_all
      end
    end
  end
end
