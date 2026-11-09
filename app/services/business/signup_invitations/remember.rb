module Business
  module SignupInvitations
    # 新規登録の直後に、未ログインで開いていた招待用URL(Devise が保存した戻り先)を会員の招待先として記録する。
    # 招待用URLでない・対象が無い場合は記録しない。戻り値: 記録したら true
    class Remember
      def self.call(customer:, path:, now: Time.current)
        new(customer, path, now).call
      end

      def initialize(customer, path, now)
        @customer = customer
        @path = path
        @now = now
      end

      def call
        return false unless @customer&.persisted? && @customer.business_user?

        type, id = Target.parse(@path)
        return false unless type && Target.path_for(type, id)

        invitation = BusinessSignupInvitation.find_or_initialize_by(customer: @customer)
        invitation.update!(target_type: type, target_id: id, expires_at: @now + BusinessSignupInvitation::TTL)
        true
      end
    end
  end
end
