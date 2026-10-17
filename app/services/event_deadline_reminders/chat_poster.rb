module EventDeadlineReminders
  # 確保済み(sending)のリマインドを、開催コミュニティのチャットへ1件だけ投稿する。
  #
  # 投稿は system_generated: true の ChatMessage として作り、画面で「自動お知らせ」と表示する。
  # 投稿者名義はイベント主催者(退会済み・コミュニティ外なら コミュニティオーナー)。
  # 一般メンバーの投稿経路(ChatMessagesController)は使わず、このサービスだけが作成する。
  #
  # 投稿後はコミュニティメンバーへアプリ内通知(group_chat)だけを作り、通常のチャット投稿で
  # 送られる「チャット投稿メール」は送らない(メール配信方式との二重通知を避けるため)。
  class ChatPoster
    class DeliveryError < StandardError; end

    def initialize(reminder, now: Time.current)
      @reminder = reminder
      @event = reminder.event
      @community = @event.community
      @now = now
    end

    def call
      chat_room = community_chat_room
      raise DeliveryError, "コミュニティチャットのルームが見つかりません" if chat_room.nil?

      author = resolve_author
      raise DeliveryError, "投稿者にできる有効なメンバー(主催者・コミュニティオーナー)がいません" if author.nil?

      chat_message = nil
      ActiveRecord::Base.transaction do
        @reminder.lock!
        next unless @reminder.sending? && @reminder.chat_message_id.nil?

        chat_message = ChatMessage.create!(
          chat_room: chat_room,
          community: @community,
          customer: author,
          content: MessageBuilder.call(event: @event, kind: @reminder.kind, sent_at: @now).chat_body,
          content_format: :markdown,
          system_generated: true
        )
        @reminder.update!(
          status: :sent,
          chat_message: chat_message,
          sent_at: Time.current,
          sent_channel: :chat,
          sent_for_deadline: @reminder.deadline,
          failure_reason: nil
        )
      end
      return if chat_message.nil?

      after_post(chat_message, author)
    end

    private

    # コミュニティ参加承認時(CommunityCustomersController#create)と同じく、
    # オーナーが参加しているコミュニティ用ルームを正とする。
    def community_chat_room
      rows = ChatRoomCustomer.where(community_id: @community.id).where.not(chat_room_id: nil)
      row = rows.where(customer_id: @community.owner_id).order(:id).first || rows.order(:id).first
      row&.chat_room
    end

    def resolve_author
      [@event.customer, @community.owner].compact.detect do |customer|
        !customer.is_deleted? && CommunityCustomer.exists?(community_id: @community.id, customer_id: customer.id)
      end
    end

    # 投稿自体は確定済みのため、ここでの失敗は投稿を取り消さずログだけ残す。
    def after_post(chat_message, author)
      Chat::LinkPreviewSyncService.call(chat_message)
      @community.active_customers.where.not(id: author.id).distinct.find_each do |member|
        member.create_notification_group_chat(author, @community.id)
      end
    rescue StandardError => e
      Rails.logger.error("[EventDeadlineReminders::ChatPoster] reminder=#{@reminder.id} after_post #{e.class}: #{e.message}")
    end
  end
end
