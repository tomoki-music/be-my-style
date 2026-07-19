module Chat
  # DM(chat_room)またはコミュニティチャットへの参加権限を判定する。
  # 投稿(ChatMessagesController#create/community_create)・一覧閲覧(#show/#community_show)・
  # スレッド取得(#thread)・スレッド投稿(#thread_reply)・返信先解決(ReplyTargetResolver)で
  # 同一の判定を使い、チェック漏れ・判定のズレを防ぐ。
  #
  # readable?/postable?は現時点ではどちらもparticipant?と同一の判定に委譲しているが、
  # 呼び出し側は「閲覧の可否を聞いている」「投稿の可否を聞いている」を意図で使い分ける。
  # 将来「閲覧のみ許可(投稿不可)」のプラン・状態が生まれた場合に、この2つを個別実装へ
  # 分離するだけで済むようにするための設計(呼び出し側のコードは変更不要)。
  class ChatRoomAuthorization
    def self.participant?(chat_room:, community:, customer:)
      new(chat_room, community, customer).participant?
    end

    def self.readable?(chat_room:, community:, customer:)
      new(chat_room, community, customer).readable?
    end

    def self.postable?(chat_room:, community:, customer:)
      new(chat_room, community, customer).postable?
    end

    def initialize(chat_room, community, customer)
      @chat_room = chat_room
      @community = community
      @customer = customer
    end

    def participant?
      return false if @customer.blank? || @chat_room.blank?

      if @community.present?
        CommunityCustomer.where(community_id: @community.id, customer_id: @customer.id).exists?
      else
        # DM文脈の参加者判定はcommunity_id: nilのChatRoomCustomer行に限定する。
        # 限定しないと、同じcustomer_idを持つ別文脈(コミュニティ用chat_room)の行を
        # 誤ってDMの参加者と判定してしまい、DM/コミュニティ間のクロス漏洩につながる。
        ChatRoomCustomer.where(chat_room_id: @chat_room.id, customer_id: @customer.id, community_id: nil).exists?
      end
    end

    def readable?
      participant?
    end

    def postable?
      participant?
    end
  end
end
