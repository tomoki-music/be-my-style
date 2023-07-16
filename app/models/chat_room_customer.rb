class ChatRoomCustomer < ApplicationRecord
  belongs_to :chat_room, optional: true
  belongs_to :customer, optional: true
  belongs_to :community, optional: true
end
