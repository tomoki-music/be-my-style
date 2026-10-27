module Business
  module Memberships
    # 会員がプロジェクトの「参加する / 参加を申請する」を押したときの処理。
    # 承認済みの親コミュニティ参加が前提。自動承認なら即参加、手動承認なら承認待ちを作る。
    #
    # 戻り値: :joined / :requested / :already_member / :already_requested / :suspended /
    #         :community_required / :closed / :unavailable
    class JoinProject
      def self.call(project:, customer:)
        new(project, customer).call
      end

      def initialize(project, customer)
        @project = project
        @customer = customer
      end

      def call
        return :unavailable if @customer.is_deleted?
        return :already_member if @customer.business_project_participant?(@project)
        return :community_required unless @customer.business_community_member?(@project.community)

        @project.with_lock do
          next :suspended if @customer.business_project_suspended?(@project)
          next :already_member if @customer.business_project_participant?(@project)
          next :already_requested if @customer.business_project_pending?(@project)
          next :closed if @project.deadline_passed?

          if @project.join_auto?
            ProjectMember.create!(project: @project, customer: @customer)
            :joined
          else
            ProjectJoinRequest.create!(project: @project, customer: @customer)
            :requested
          end
        end
      rescue ActiveRecord::RecordNotUnique
        @project.join_auto? ? :already_member : :already_requested
      end
    end
  end
end
