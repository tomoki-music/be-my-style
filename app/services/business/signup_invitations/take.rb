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
    #             (reason: :project_invitation は、プライベートプロジェクトの招待リンクが無効化された・参加できない場合)
    #
    # プライベートプロジェクトの招待リンクから登録した人は、ここで招待を受け入れて参加を成立させてから(:ok)プロジェクトへ案内する。
    class Take
      Result = Struct.new(:status, :path, :record, :reason)

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
        return take_project_invitation(invitation) if invitation.project_invitation_link_id.present?

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

      private

      def take_project_invitation(invitation)
        link = invitation.project_invitation_link
        invitation.destroy!
        return Result.new(:invalid, nil, nil, :project_invitation) if invitation.expired?(@now)

        result = Business::Memberships::AcceptProjectInvitation.call(link: link, customer: @customer, check_expiry: false, now: @now)
        return Result.new(:invalid, nil, nil, :project_invitation) unless %i[joined already_member].include?(result)

        Result.new(:ok, Target.path_of(link.project), link.project)
      end
    end
  end
end
