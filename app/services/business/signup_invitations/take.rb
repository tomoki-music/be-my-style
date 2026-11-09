module Business
  module SignupInvitations
    # オンボーディング完了時に招待先を取り出す。
    #
    # 戻り値の status:
    #   :none     招待先の記録が無い
    #   :ok       path(対象を読み直して確かめた詳細画面)へ案内する。記録は削除する(次回以降のログインで再び転送しない)
    #   :awaiting 招待先のプロジェクトを開くには、先に親コミュニティへの参加が必要。path(コミュニティの詳細画面)へ案内し、
    #             参加が成立するまで記録を残す(Resume が参加成立後にプロジェクトへ案内する)。期限は AWAITING_TTL へ延ばす
    #   :invalid  期限切れ・対象が削除済みなど。記録は削除し、呼び出し側は通常の遷移先へ戻す
    class Take
      Result = Struct.new(:status, :path, :record)

      def self.call(customer, now: Time.current)
        new(customer, now).call
      end

      def initialize(customer, now)
        @customer = customer
        @now = now
      end

      def call
        invitation = @customer && BusinessSignupInvitation.find_by(customer_id: @customer.id)
        return Result.new(:none) unless invitation

        record = invitation.expired?(@now) ? nil : Target.find(invitation.target_type, invitation.target_id)
        unless record
          invitation.destroy!
          return Result.new(:invalid)
        end

        if Target.openable?(@customer, record)
          invitation.destroy!
          return Result.new(:ok, Target.path_of(record), record)
        end

        invitation.update!(expires_at: @now + BusinessSignupInvitation::AWAITING_TTL)
        Result.new(:awaiting, Target.path_of(record.community), record)
      end
    end
  end
end
