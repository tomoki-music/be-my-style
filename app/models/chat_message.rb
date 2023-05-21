class ChatMessage < ApplicationRecord
  belongs_to :chat_room
  belongs_to :customer

  validates :content, presence: true
end
