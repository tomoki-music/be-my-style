module Business
  module Memberships
    # プロジェクト管理者による承認待ち申請の承認。権限の確認は呼び出し側(コントローラ)で行う。
    # 承認時点で親コミュニティの参加資格を失っていれば承認せず、申請を消す。
    #
    # 戻り値: :approved / :not_found / :withdrawn / :community_required / :suspended
    class ApproveProjectRequest
      def self.call(project:, request_id:)
        new(project, request_id).call
      end

      def initialize(project, request_id)
        @project = project
        @request_id = request_id
      end

      def call
        @project.with_lock do
          request = @project.project_join_requests.includes(:customer).find_by(id: @request_id)
          next :not_found unless request

          customer = request.customer
          next :withdrawn if customer.is_deleted?

          unless customer.business_community_member?(@project.community)
            request.destroy!
            next :community_required
          end

          if customer.business_project_suspended?(@project)
            request.destroy!
            next :suspended
          end

          ProjectMember.create!(project: @project, customer: customer) unless @project.project_members.exists?(customer_id: customer.id)
          request.destroy!
          :approved
        end
      end
    end
  end
end
