module Business
  module ProjectThreads
    # スレッドへの投稿(本文・添付のみ・スタンプ)を、プロジェクトの参加者へ画面内の通知とメールで知らせる。
    # 宛先は Project#thread_post_notification_recipients(投稿者本人は除く)。
    #
    # 同じ投稿・同じ宛先の通知は1件だけ((project_chat_id, visited_id) の一意制約)。再実行・同時実行では
    # 先に保存できた1回だけが通知を作り、メールはその通知の保存がコミットされた後に登録する(Notification)。
    # 保存されていない投稿(検証エラー・巻き戻し)では何もしない。
    #
    # 戻り値: 新しく通知した会員の配列
    class NotifyPost
      ACTION = "project_message".freeze

      def self.call(chat)
        new(chat).call
      end

      def initialize(chat)
        @chat = chat
        @project = chat.project
        @poster = chat.customer
      end

      def call
        return [] unless @chat.persisted? && ProjectChat.exists?(@chat.id)

        @project.thread_post_notification_recipients(except: @poster).select { |customer| create_notification(customer) }
      end

      private

      # 既にあるかを先に調べず、一意制約に任せる(調べてから作る間に、同時実行の側が作ることがあるため)。
      # 重複時に外側のトランザクションまで巻き戻さないよう、セーブポイントの中で保存する。
      def create_notification(customer)
        notification = Notification.new(
          visitor: @poster,
          visited: customer,
          action: ACTION,
          community_id: @project.community_id,
          project_id: @project.id,
          project_chat_id: @chat.id,
          hidden_in_app: !customer.business_in_app_notifications_enabled?
        )
        # 画面内の通知をオフにしていても通知のレコードは作る(メールはこの通知の保存を起点に送るため)。
        notification.deliver_project_chat_mail = customer.business_email_notifications_enabled?
        Notification.transaction(requires_new: true) { notification.save! }
        true
      rescue ActiveRecord::RecordNotUnique
        false
      end
    end
  end
end
