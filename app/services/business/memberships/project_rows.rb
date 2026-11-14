module Business
  module Memberships
    # コミュニティの参加資格が無くなった(または新たに参加し直す)会員の、配下プロジェクトでの
    # 参加済み・承認待ちを消す。再参加しても過去のプロジェクト参加資格が復活しないようにするため。
    # プロジェクトのアクセス停止は残す(停止は運営判断のため、再参加で解除しない)。
    #
    # プライベートプロジェクトの参加は招待によるもので、親コミュニティへの所属とは独立している。
    # そのため既定(keep_private: true)では消さない。親コミュニティでのアクセス停止のときだけ呼び出し側が false を渡して消す。
    module ProjectRows
      def self.clear!(community:, customer:, keep_private: true)
        projects = community.projects
        projects = projects.where.not(visibility: Project.visibilities[:private]) if keep_private
        project_ids = projects.select(:id)
        ProjectMember.where(customer_id: customer.id, project_id: project_ids).destroy_all
        ProjectJoinRequest.where(customer_id: customer.id, project_id: project_ids).destroy_all
      end
    end
  end
end
