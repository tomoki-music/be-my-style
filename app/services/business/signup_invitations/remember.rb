module Business
  module SignupInvitations
    # 新規登録の直後に、未ログインで開いていた招待用URL(Devise が保存した戻り先)を会員の招待先として記録する。
    # 招待用URLでない・対象が無い場合は記録しない。戻り値: 記録したら true
    #
    # プライベートプロジェクトの招待リンクから来た人(戻り先が招待の受け入れ画面で、このブラウザで開いたリンクが有効)は、
    # リンクも一緒に記録する。オンボーディング完了時(Take)にこのリンクで参加を成立させる。
    class Remember
      PROJECT_INVITATION_PATH = "/business/project_invitation".freeze

      def self.call(customer:, path:, project_invitation_link_id: nil, now: Time.current)
        new(customer, path, project_invitation_link_id, now).call
      end

      def initialize(customer, path, project_invitation_link_id, now)
        @customer = customer
        @path = path
        @project_invitation_link_id = project_invitation_link_id
        @now = now
      end

      def call
        return false unless @customer&.persisted? && @customer.business_user?
        return remember_project_invitation if @path.to_s == PROJECT_INVITATION_PATH

        type, id = Target.parse(@path)
        return false unless type && Target.path_for(type, id)

        invitation = BusinessSignupInvitation.find_or_initialize_by(customer: @customer)
        invitation.update!(target_type: type, target_id: id, expires_at: @now + BusinessSignupInvitation::TTL, project_invitation_link: nil)
        true
      end

      private

      def remember_project_invitation
        link = @project_invitation_link_id.presence && ProjectInvitationLink.find_by(id: @project_invitation_link_id)
        return false unless link&.usable?(@now)

        invitation = BusinessSignupInvitation.find_or_initialize_by(customer: @customer)
        invitation.update!(target_type: "Project", target_id: link.project_id, project_invitation_link: link,
                           expires_at: @now + BusinessSignupInvitation::TTL)
        true
      end
    end
  end
end
