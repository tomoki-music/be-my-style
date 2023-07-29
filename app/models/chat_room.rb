class ChatRoom < ApplicationRecord
  has_many :chat_room_customers, dependent: :destroy
  has_many :customers, through: :chat_room_customers, dependent: :destroy
  has_many :communities, through: :chat_room_customers, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
end
