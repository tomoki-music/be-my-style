module Chat
  # クライアントから送られたquoted_chat_message_idを信用せず、現在のチャット文脈
  # (chat_room / community)に属し、current_customerが参加者であることを検証した上で
  # 対象ChatMessageを返す。条件を満たさない場合は例外を投げず静かにnilを返す
  # (引用なしの通常投稿として保存させる)。
  #
  # Chat::ReplyTargetResolverと異なり、引用元はスレッド親(thread_root)へ正規化しない。
  # 引用はスレッド親子関係とは独立した概念であり、スレッド内の返信メッセージ自体を
  # 名指しで引用できる必要があるため、解決した対象をそのまま返す。
  #
  # 同一chat_room内かどうかの判定はcandidate.chat_room_id == @chat_room.idのみで行い、
  # ChatMessage#community_idの一致は見ない。community_idは「元々どこにも設定されておらず
  # 常にnilだった(既存のバグ)」経緯があり(Public::ChatMessagesController参照)、
  # 過去に作成されたコミュニティメッセージがcommunity_id: nilのまま残っている場合がある。
  # chat_room自体がDM/コミュニティのどちらか一方の文脈でしか使われない設計のため、
  # chat_room_idの一致だけで文脈の同一性を安全に判定でき、community_idの不整合な値に
  # 引きずられて正当な引用が拒否される事故を防げる。
  class QuoteTargetResolver
    def self.call(quoted_chat_message_id:, chat_room:, community:, current_customer:)
      new(quoted_chat_message_id, chat_room, community, current_customer).resolve
    end

    def initialize(quoted_chat_message_id, chat_room, community, current_customer)
      @quoted_chat_message_id = quoted_chat_message_id
      @chat_room = chat_room
      @community = community
      @current_customer = current_customer
    end

    def resolve
      return nil if @quoted_chat_message_id.blank?
      return nil if @current_customer.blank?

      candidate = ChatMessage.find_by(id: @quoted_chat_message_id)
      return nil if candidate.blank?
      return nil unless candidate.chat_room_id == @chat_room.id
      return nil unless Chat::ChatRoomAuthorization.postable?(
        chat_room: @chat_room, community: @community, customer: @current_customer
      )

      candidate
    end
  end
end
