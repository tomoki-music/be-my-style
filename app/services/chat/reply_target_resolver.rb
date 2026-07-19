module Chat
  # クライアントから送られたreply_to_chat_message_idを信用せず、現在のチャット文脈
  # (chat_room / community)に属し、current_customerが参加者であることを検証した上で
  # 対象ChatMessageを返す。条件を満たさない場合は例外を投げず静かにnilを返す
  # (返信リンクの無い通常投稿として保存させる)。
  #
  # 解決した対象が既に返信メッセージ(スレッド内の1件)だった場合は、スレッドが
  # 階層化しないよう常にそのスレッドの親(thread_root)を返す。
  class ReplyTargetResolver
    def self.call(reply_to_chat_message_id:, chat_room:, community:, current_customer:)
      new(reply_to_chat_message_id, chat_room, community, current_customer).resolve
    end

    def initialize(reply_to_chat_message_id, chat_room, community, current_customer)
      @reply_to_chat_message_id = reply_to_chat_message_id
      @chat_room = chat_room
      @community = community
      @current_customer = current_customer
    end

    def resolve
      return nil if @reply_to_chat_message_id.blank?
      return nil if @current_customer.blank?

      candidate = ChatMessage.find_by(id: @reply_to_chat_message_id)
      return nil if candidate.blank?
      return nil unless candidate.chat_room_id == @chat_room.id
      return nil unless candidate.community_id == @community&.id
      return nil unless Chat::ChatRoomAuthorization.postable?(
        chat_room: @chat_room, community: @community, customer: @current_customer
      )

      candidate.thread_root
    end
  end
end
