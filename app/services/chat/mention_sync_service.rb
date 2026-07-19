module Chat
  # 保存済みChatMessageの本文からメンションを抽出し、ChatMentionレコードと通知を作成する。
  # 呼び出し側(コントローラー)がメッセージ保存と同じトランザクション内で呼び出すことで、
  # 「投稿失敗時にChatMentionだけ残る」事態を防ぐ。
  #
  # 新規投稿・編集の両方で同じ呼び出し方(.call(chat_message, ...))を使う。
  # 「新規投稿時は前回のChatMentionが存在しない」というだけなので、以下の差分ロジックは
  # 呼び出し側で新規/編集を区別する必要なく両方に対応する:
  #   - 前回同期時点のChatMentionに存在せず、今回新たに抽出された相手 → 作成+通知
  #   - 前回・今回の両方に存在する相手 → ChatMentionは維持し、通知はしない(再通知防止)
  #   - 前回は存在したが今回の本文から消えた相手 → ChatMentionを削除(通知もしない)
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
      # 前回同期時点(=このメソッド呼び出し前)のメンション対象。新規投稿時は常に空。
      previously_mentioned_ids = @chat_message.chat_mentions.pluck(:mentioned_customer_id)

      customer_ids = MentionParser.call(@chat_message.content)
      eligible_customers = eligible_scope.where(id: customer_ids)
      current_ids = eligible_customers.map(&:id)

      ActiveRecord::Base.transaction do
        removed_ids = previously_mentioned_ids - current_ids
        @chat_message.chat_mentions.where(mentioned_customer_id: removed_ids).destroy_all if removed_ids.present?

        eligible_customers.map do |mentioned_customer|
          mention = ChatMention.find_or_create_by!(
            chat_message: @chat_message,
            mentioned_customer: mentioned_customer
          )
          notify(mentioned_customer) unless previously_mentioned_ids.include?(mentioned_customer.id)
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
