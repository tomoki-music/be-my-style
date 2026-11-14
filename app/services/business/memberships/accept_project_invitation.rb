module Business
  module Memberships
    # 招待リンクを受け入れて、プライベートプロジェクトに参加する。
    #
    # check_expiry: false は、期限内にリンクを開いて新規登録を始めた人(BusinessSignupInvitation に記録済み)が、
    # 確認メール・オンボーディングを終えた時点で期限を過ぎていても参加できるようにするため。無効化・再発行は常に拒否する。
    #
    # 戻り値: :joined / :already_member / :invalid(期限切れ・無効化・プライベートでない) / :suspended /
    #         :business_required / :unavailable
    class AcceptProjectInvitation
      def self.call(link:, customer:, check_expiry: true, now: Time.current)
        new(link, customer, check_expiry, now).call
      end

      def initialize(link, customer, check_expiry, now)
        @link = link
        @customer = customer
        @check_expiry = check_expiry
        @now = now
      end

      def call
        return :invalid unless @link && acceptable_link?
        return :unavailable if @customer.is_deleted?
        return :business_required unless @customer.business_eligible?

        project = @link.project
        return :already_member if @customer.business_project_participant?(project)

        result = project.with_lock do
          @link.reload
          next :invalid unless acceptable_link?
          next :suspended if suspended?(project)
          next :already_member if @customer.business_project_participant?(project)

          ProjectMember.create!(project: project, customer: @customer) unless project.project_members.exists?(customer_id: @customer.id)
          ProjectJoinRequest.where(project_id: project.id, customer_id: @customer.id).destroy_all
          @link.record_use!(@now)
          :joined
        end

        NotifyProjectJoined.call(project: project, actor: @customer) if result == :joined
        result
      rescue ActiveRecord::RecordNotUnique
        :already_member
      end

      private

      def acceptable_link?
        status = @link.status(@now)
        status == :active || (!@check_expiry && status == :expired)
      end

      def suspended?(project)
        @customer.business_project_suspended?(project) || @customer.business_community_suspended?(project.community)
      end
    end
  end
end
