class ChatMessage < ApplicationRecord
  belongs_to :chat_room
  belongs_to :customer
end
