module Chat
  # 保存済みChatMessageの本文からメンションを抽出し、ChatMentionレコードと通知を作成する。
  # 呼び出し側(コントローラー)がメッセージ保存と同じトランザクション内で呼び出すことで、
  # 「投稿失敗時にChatMentionだけ残る」事態を防ぐ。
  class MentionSyncService
    # skip_notification_customer_ids: 既に返信通知(Chat::ReplyNotificationService)を受け取った
    # 相手のcustomer_id。ChatMention自体は本文表示のため通常通り作成するが、
    # 同一メッセージ・同一相手への重複通知を避けるため通知作成だけ抑制する。
    def self.call(chat_message, skip_notification_customer_ids: [])
      new(chat_message, skip_notification_customer_ids).sync
    end

    def initialize(chat_message, skip_notification_customer_ids = [])
      @chat_message = chat_message
      @skip_notification_customer_ids = skip_notification_customer_ids
    end

    def sync
      customer_ids = MentionParser.call(@chat_message.content)
      return [] if customer_ids.blank?

      eligible_customers = eligible_scope.where(id: customer_ids)
      return [] if eligible_customers.blank?

      ActiveRecord::Base.transaction do
        eligible_customers.map do |mentioned_customer|
          mention = ChatMention.find_or_create_by!(
            chat_message: @chat_message,
            mentioned_customer: mentioned_customer
          )
          notify(mentioned_customer)
          mention
        end
      end
    end

    private

    def eligible_scope
      if @chat_message.community_id.present?
        MentionCandidates.for_community(community: @chat_message.community, current_customer: @chat_message.customer)
      else
        MentionCandidates.for_chat_room(chat_room: @chat_message.chat_room, current_customer: @chat_message.customer)
      end
    end

    def notify(mentioned_customer)
      return if @skip_notification_customer_ids.include?(mentioned_customer.id)

      if @chat_message.community_id.present?
        mentioned_customer.create_notification_mention_community(@chat_message.customer, @chat_message)
      else
        mentioned_customer.create_notification_mention_dm(@chat_message.customer, @chat_message)
      end
    end
  end
end
