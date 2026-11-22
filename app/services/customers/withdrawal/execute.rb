module Customers
  module Withdrawal
    # 本人による退会の確定。Customer は destroy せず(ほかの人のイベント・投稿・会話の履歴を壊さないため)、
    # 利用停止(withdrawn_at / is_deleted) + プロフィールなど不要な個人情報の削除 + 開催前の予定の取消 を行う。
    #
    # - DB の変更は1つのトランザクションにまとめる(途中で失敗したら何も変わらない)。
    # - 会員の行をロックし、同じ会員の二重実行は2回目を :already_withdrawn にする。
    # - 確定できない理由(Plan#blockers)はロックした後に判定し直す(確認画面を開いた後の変化に対応)。
    # - ファイル(プロフィール画像・歌声の音声など)の削除は外部ストレージへの操作のため、コミット後に
    #   PurgeFiles で行う。失敗しても退会は成立したままにし、再実行できる(rake customers:withdrawal:purge_files)。
    # - 外部への通知はこの処理からは送らない(退会完了メールも送らない)。
    # - 旧方式の退会(管理画面で is_deleted だけを立てた会員。withdrawn_at は空で個人情報が残っている)は、
    #   既定では処理済みとして扱う。include_legacy_deleted: true のとき(管理画面で明示的に選んだ1名)だけ処理する。
    #   is_deleted は処理中も true のまま変えないため、ログイン・通知が再び有効になることはない。
    #   止める理由がある・途中で失敗したときは、トランザクションにより旧方式の退会状態のまま残る。
    class Execute
      Result = Struct.new(:status, :plan, keyword_init: true) do
        def withdrawn?
          status == :withdrawn
        end

        def already_withdrawn?
          status == :already_withdrawn
        end

        def blocked?
          status == :blocked
        end
      end

      # プロフィールとして本人が入力した情報・ログイン関連の情報。退会時に消す(name / email は置き換える)。
      CLEARED_ATTRIBUTES = %i[
        postal_code address tell introduction sex birthday activity_stance
        favorite_artist1 favorite_artist2 favorite_artist3 favorite_artist4 favorite_artist5
        url prefecture_id job skills achievements singing_profile_comment
        reset_password_token reset_password_sent_at remember_created_at
        confirmation_token confirmation_sent_at unconfirmed_email
        current_sign_in_ip last_sign_in_ip last_active_at
        profile_image_position_x profile_image_position_y
      ].freeze

      def self.call(customer, now: Time.current, include_legacy_deleted: false)
        new(customer, now: now, include_legacy_deleted: include_legacy_deleted).call
      end

      def initialize(customer, now: Time.current, include_legacy_deleted: false)
        @customer = customer
        @now = now
        @include_legacy_deleted = include_legacy_deleted
      end

      def call
        result = ActiveRecord::Base.transaction do
          @customer.lock!

          if @customer.withdrawn? || (@customer.is_deleted? && !@include_legacy_deleted)
            Result.new(status: :already_withdrawn)
          else
            plan = Plan.new(@customer, now: @now)
            if plan.withdrawable?
              release_upcoming_participation!(plan)
              remove_personal_data!
              anonymize_account!
              Result.new(status: :withdrawn, plan: plan)
            else
              Result.new(status: :blocked, plan: plan)
            end
          end
        end

        PurgeFiles.call(@customer) if result.withdrawn?
        result
      end

      private

      # 開催前の予定から外れる。エントリーの取消は本人の「取消」と同じく参加の行を消すだけ(主催者への通知は既存の取消と同じく無し)。
      # 参加申請は取り下げる(Permit / ProjectJoinRequest の削除で、承認者の通知も既読になる)。
      def release_upcoming_participation!(plan)
        JoinPartCustomer.where(id: plan.cancellable_entries.map(&:id)).destroy_all
        plan.pending_community_requests.each(&:destroy!)
        plan.pending_project_requests.each(&:destroy!)

        EntryInvitation.where(customer_id: @customer.id, status: :pending)
                       .update_all(status: EntryInvitation.statuses[:skipped],
                                   failure_reason: EntryInvitations::Sender::WITHDRAWN_FAILURE_REASON,
                                   updated_at: @now)

        # 運営者・イベント編集者としての権限(ほかに管理できる人がいることは Plan で確認済み)。
        @customer.community_owners.destroy_all
        @customer.community_event_editors.destroy_all
      end

      # ほかの人の履歴に関わらない、本人だけの情報を消す。投稿・コメント・チャット・過去のイベント参加は残す。
      def remove_personal_data!
        Relationship.where(follower_id: @customer.id).or(Relationship.where(followed_id: @customer.id)).delete_all
        # 自分宛ての通知(もう誰も見ない)。自分が起こした通知は相手の履歴なので残す(表示は「退会済みユーザー」)。
        Notification.unscoped.where(visited_id: @customer.id).delete_all

        CustomerPart.where(customer_id: @customer.id).delete_all
        CustomerGenre.where(customer_id: @customer.id).delete_all
        CustomerSongPart.where(customer_id: @customer.id).delete_all
        @customer.member_profile&.destroy!
        @customer.business_notification_setting&.destroy!
        BusinessSignupInvitation.where(customer_id: @customer.id).delete_all
        # 学習サービスの LINE 連携(外部サービスの ID と連携用トークン)。
        @customer.learning_line_connections.destroy_all

        # 歌声診断はランキング・シーズン履歴などの集計に使われているため行は残し、公開表示の対象から外す。
        @customer.singing_diagnoses.update_all(ranking_opt_in: false, updated_at: @now)
      end

      # ログインできない状態にし、名前とメールアドレスを置き換える。
      # パスワードを作り直すと Devise のセッション・ログイン保持 Cookie の照合値(authenticatable_salt)が変わり、
      # 別の端末・ブラウザに残っているログインも無効になる。
      # Devise の再確認メールや検証(既存データの形式違い)で退会が止まらないよう、update_columns で保存する。
      def anonymize_account!
        attributes = CLEARED_ATTRIBUTES.index_with(nil).merge(
          name: Customer::WITHDRAWN_NAME,
          email: placeholder_email,
          encrypted_password: Devise::Encryptor.digest(Customer, SecureRandom.base58(48)),
          confirm_mail: false,
          is_deleted: true,
          withdrawn_at: @now,
          updated_at: @now
        )
        @customer.update_columns(attributes)
      end

      # 同じメールアドレスで新しく登録できるよう、元のアドレスは残さない。届かない宛先(予約済みドメイン)にし、
      # 会員 ID と乱数で一意にする(customers.email の一意制約)。
      def placeholder_email
        "withdrawn-#{@customer.id}-#{SecureRandom.hex(8)}@#{WithdrawnMailInterceptor::DOMAIN}"
      end
    end
  end
end
