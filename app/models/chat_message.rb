class ChatMessage < ApplicationRecord
  belongs_to :chat_room
  belongs_to :customer
  belongs_to :community, optional: true

  validates :content, presence: true
end
