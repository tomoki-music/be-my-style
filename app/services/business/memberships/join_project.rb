module Business
  module Memberships
    # 会員がプロジェクトの「参加する / 参加を申請する」を押したときの処理。
    # 承認済みの親コミュニティ参加が前提。自動承認なら即参加、手動承認なら承認待ちを作る。
    #
    # message は手動承認の申請に添える任意の文(自動承認では使わない)。
    #
    # 戻り値: :joined / :requested / :already_member / :already_requested / :suspended /
    #         :community_required / :business_required / :unavailable / :message_too_long
    class JoinProject
      def self.call(project:, customer:, message: nil)
        new(project, customer, message).call
      end

      def initialize(project, customer, message)
        @project = project
        @customer = customer
        @message = message.to_s.strip.presence
      end

      def call
        return :unavailable if @customer.is_deleted?
        return :business_required unless @customer.business_eligible?
        return :already_member if @customer.business_project_participant?(@project)
        return :community_required unless @customer.business_community_member?(@project.community)
        return :message_too_long if message_too_long?

        @project.with_lock do
          next :suspended if @customer.business_project_suspended?(@project)
          next :already_member if @customer.business_project_participant?(@project)
          next :already_requested if @customer.business_project_pending?(@project)

          if @project.join_auto?
            ProjectMember.create!(project: @project, customer: @customer)
            :joined
          else
            ProjectJoinRequest.create!(project: @project, customer: @customer, message: @message)
            :requested
          end
        end
      rescue ActiveRecord::RecordNotUnique
        @project.join_auto? ? :already_member : :already_requested
      end

      private

      def message_too_long?
        !@project.join_auto? && @message.to_s.length > ProjectJoinRequest::MESSAGE_MAX_LENGTH
      end
    end
  end
end
