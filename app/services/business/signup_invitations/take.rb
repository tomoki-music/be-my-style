module Business
  module SignupInvitations
    # オンボーディング完了時に招待先を1回だけ取り出す。取り出した記録は有効・無効にかかわらず削除する
    # (次回以降のログインで再び招待先へ転送しない)。
    #
    # 戻り値の status:
    #   :none    招待先の記録が無い
    #   :ok      path へ案内する(対象を読み直して確かめた詳細画面のパス)
    #   :invalid 期限切れ・対象が削除済みなど。呼び出し側は通常の遷移先へ戻す
    class Take
      Result = Struct.new(:status, :path)

      def self.call(customer, now: Time.current)
        new(customer, now).call
      end

      def initialize(customer, now)
        @customer = customer
        @now = now
      end

      def call
        invitation = @customer && BusinessSignupInvitation.find_by(customer_id: @customer.id)
        return Result.new(:none, nil) unless invitation

        invitation.destroy!
        return Result.new(:invalid, nil) if invitation.expired?(@now)

        path = Target.path_for(invitation.target_type, invitation.target_id)
        path ? Result.new(:ok, path) : Result.new(:invalid, nil)
      end
    end
  end
end
