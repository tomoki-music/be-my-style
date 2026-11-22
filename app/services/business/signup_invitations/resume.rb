module Business
  module SignupInvitations
    # オンボーディング後も残っている招待先(親コミュニティへの参加待ちのプロジェクト)へ、参加が成立して開けるようになったら案内する。
    # 呼ぶのは、自動承認での参加直後(Business::PermitsController)・ログイン直後(Public::SessionsController)・
    # 承認後にコミュニティを開いたとき(Business::CommunitiesController#show)。
    #
    # 戻り値: 案内するプロジェクトの詳細画面のパス(記録は削除する)。まだ開けない・記録が無いときは nil(記録は残す)。
    # 期限切れ・対象が削除済みの記録は、ここで削除して nil を返す。
    class Resume
      def self.call(customer, community: nil, now: Time.current)
        new(customer, community, now).call
      end

      def initialize(customer, community, now)
        @customer = customer
        @community = community
        @now = now
      end

      def call
        return unless @customer&.onboarding_done?

        invitation = BusinessSignupInvitation.find_by(customer_id: @customer.id)
        return unless invitation
        # 招待リンクからの登録は、オンボーディング完了時(Take)に参加まで済ませる。残っていればここで同じ処理をする。
        return take_project_invitation if invitation.project_invitation_link_id.present?

        record = invitation.expired?(@now) ? nil : Target.find(invitation.target_type, invitation.target_id)
        unless record
          invitation.destroy!
          return
        end
        return if @community && record.respond_to?(:community) && record.community != @community
        return unless Target.openable?(@customer, record)

        invitation.destroy!
        Target.path_of(record)
      end

      private

      def take_project_invitation
        result = Take.call(@customer, now: @now)
        return unless result.status == :ok
        return if @community && result.record.community != @community

        result.path
      end
    end
  end
end
