module Chat
  # コミュニティチャット左側のメンバー一覧。
  # chat_room_customers には (chat_room_id, customer_id) の一意制約が無く、過去の参加申請の重複承認などで
  # 同じ人の行が複数残っていることがあるため、Customer ID で1人1回に絞る。
  # 表示名では判定しない(同名の別ユーザーは両方表示する)。並びは最初に参加した行の順(id順)を保つ。
  class CommunityRoomMembers
    def self.call(chat_room)
      new(chat_room).members
    end

    def initialize(chat_room)
      @chat_room = chat_room
    end

    def members
      ChatRoomCustomer.where(chat_room_id: @chat_room.id)
        .order(:id)
        .includes(customer: { profile_image_attachment: :blob })
        .map(&:customer)
        .compact
        .reject(&:is_deleted)
        .uniq(&:id)
    end
  end
end
