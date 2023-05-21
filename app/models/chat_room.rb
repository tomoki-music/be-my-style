class ChatRoom < ApplicationRecord
  has_many :chat_room_customers
  has_many :customers, through: :chat_room_customers
  has_many :chat_messages
end
