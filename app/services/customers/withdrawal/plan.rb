module Customers
  module Withdrawal
    # 退会の確認画面と確定処理の両方が使う「退会するとどうなるか」。
    #
    # blockers: 退会を確定できない理由。ほかの人の場や予定に影響するもの・自動で片付けると危ないものは、
    #           本人が解消するまで確定させない(所有権を他人へ勝手に移さない、課金を勝手に止めない)。
    # cancellable_entries: 確定時に自動で取り消す開催前イベントのエントリー(本人が取消できる期限内のもの)。
    # pending_*_requests:  確定時に取り下げる参加申請。
    class Plan
      Blocker = Struct.new(:key, :records, keyword_init: true)

      BLOCKER_KEYS = %i[
        system_admin
        active_subscription
        owned_communities
        sole_manager_communities
        hosted_events
        locked_entries
        learning_students
      ].freeze

      attr_reader :customer, :now

      def initialize(customer, now: Time.current)
        @customer = customer
        @now = now
      end

      def withdrawable?
        blockers.empty?
      end

      def blockers
        @blockers ||= BLOCKER_KEYS
          .map { |key| Blocker.new(key: key, records: send("#{key}_records")) }
          .select { |blocker| blocker.records.any? }
      end

      # 開催前で、本人が取消できる期限(開始7日前)より前のエントリー。通常の「取消」と同じ扱いで消す。
      def cancellable_entries
        upcoming_entries.select { |entry| entry.join_part.song.event.join_cancellable?(now: now) }
      end

      def pending_community_requests
        @pending_community_requests ||= customer.permits.includes(:community).order(:id).to_a
      end

      def pending_project_requests
        @pending_project_requests ||= customer.project_join_requests.includes(:project).order(:id).to_a
      end

      private

      # 運営(システム管理者)のアカウント。ほかの運営者による対応が必要なため、この画面からは退会させない。
      def system_admin_records
        customer.admin? ? [customer] : []
      end

      # Stripe で契約中の有料プラン。課金を止めずに退会すると請求だけが続くため、先に解約してもらう。
      # (Stripe の解約処理はここでは行わない。管理画面で付与しただけのプランは課金が無いので対象外)
      def active_subscription_records
        customer.subscribed? && customer.stripe_managed_subscription? ? [customer.subscription] : []
      end

      # オーナーのコミュニティ。オーナーの変更は運営だけができるため、自動では引き継がない。
      def owned_communities_records
        Community.where(owner_id: customer.id).order(:id).to_a
      end

      # 運営者(CommunityOwner)として管理していて、ほかに管理できる人がいないコミュニティ。
      def sole_manager_communities_records
        community_ids = customer.community_owners.pluck(:community_id) - Community.where(owner_id: customer.id).pluck(:id)
        Community.where(id: community_ids).order(:id).to_a.reject { |community| other_active_manager?(community) }
      end

      # 主催(投稿者)している、終了していないイベント。参加者がいるため、主催の変更か削除を先にしてもらう。
      def hosted_events_records
        Event.where(customer_id: customer.id).upcoming_or_ongoing(now).order(:event_start_time, :id).to_a
      end

      # 取消期限(開始7日前)を過ぎた・開催中のイベントへのエントリー。本人の取消と同じく、退会でも自動では外さない。
      def locked_entries_records
        upcoming_entries.reject { |entry| entry.join_part.song.event.join_cancellable?(now: now) }
      end

      # 学習サービスに登録した生徒(会員ではない第三者の情報)。生徒への連絡が途切れるため、先に整理してもらう。
      def learning_students_records
        customer.learning_students.order(:id).to_a
      end

      def upcoming_entries
        @upcoming_entries ||= JoinPartCustomer
          .where(customer_id: customer.id)
          .joins(join_part: { song: :event })
          .merge(Event.upcoming_or_ongoing(now))
          .includes(join_part: { song: :event })
          .order(:id)
          .to_a
      end

      def other_active_manager?(community)
        manager_ids = CommunityOwner.where(community_id: community.id).where.not(customer_id: customer.id).pluck(:customer_id)
        manager_ids << community.owner_id if community.owner_id.present? && community.owner_id != customer.id
        Customer.notifiable.where(id: manager_ids).exists?
      end
    end
  end
end
