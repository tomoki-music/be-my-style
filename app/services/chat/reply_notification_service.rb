module Chat
  # 保存済みChatMessageが返信の場合、返信元メッセージの投稿者へ通知(reply_dm / reply_community)を
  # 作成する。自分自身の投稿への返信では通知しない(Customer#create_notification_reply_*内のガード)。
  # 呼び出し側(コントローラー)がメッセージ保存と同じトランザクション内で呼び出す想定。
  class ReplyNotificationService
    def self.call(chat_message)
      new(chat_message).notify
    end

    def initialize(chat_message)
      @chat_message = chat_message
    end

    # 通知した相手のcustomer_id配列を返す(同一メッセージ・同一相手へのメンション通知を
    # 抑制するため、呼び出し元がChat::MentionSyncServiceへ渡す)。
    def notify
      original = @chat_message.reply_to_chat_message
      return [] if original.blank?

      author = original.customer
      return [] if author.blank?

      notified =
        if @chat_message.community_id.present?
          author.create_notification_reply_community(@chat_message.customer, @chat_message)
        else
          author.create_notification_reply_dm(@chat_message.customer, @chat_message)
        end

      notified ? [author.id] : []
    end
  end
end
