module Business
  module Memberships
    # 閲覧者から見た各プロジェクトの参加状況。条件は BusinessAccess(business_project_manager? /
    # business_project_participant?)と揃え、表示中のプロジェクト分だけを種類ごとに1回ずつ問い合わせる。
    #
    #   :operator  運営(親コミュニティの運営者)
    #   :owner     主催(親コミュニティに参加しているプロジェクト作成者)
    #   :admin     管理権限あり(システム管理者)
    #   :member    参加中
    #   :suspended アクセス停止中(再参加・再申請できない)
    #   :pending   承認待ち
    #   :none      未参加(参加する / 参加を申請する)
    class ProjectStatuses
      def self.call(customer:, projects:)
        new(customer, projects).call
      end

      def self.for(customer:, project:)
        call(customer: customer, projects: [project]).fetch(project.id)
      end

      def initialize(customer, projects)
        @customer = customer
        @projects = projects.to_a
      end

      def call
        return {} if @projects.empty?

        project_ids = @projects.map(&:id)
        community_ids = @projects.map(&:community_id).uniq
        operated = @customer.manageable_communities.where(id: community_ids).pluck(:id).to_set
        community_member = @customer.community_customers.where(community_id: community_ids).pluck(:community_id).to_set
        joined = @customer.project_members.where(project_id: project_ids).pluck(:project_id).to_set
        suspended = @customer.project_access_suspensions.where(project_id: project_ids).pluck(:project_id).to_set
        pending = @customer.project_join_requests.where(project_id: project_ids).pluck(:project_id).to_set

        @projects.to_h do |project|
          in_community = community_member.include?(project.community_id)
          status =
            if operated.include?(project.community_id) then :operator
            elsif project.customer_id == @customer.id && in_community then :owner
            elsif @customer.admin? then :admin
            elsif in_community && joined.include?(project.id) then :member
            elsif suspended.include?(project.id) then :suspended
            elsif pending.include?(project.id) then :pending
            else :none
            end
          [project.id, status]
        end
      end
    end
  end
end
