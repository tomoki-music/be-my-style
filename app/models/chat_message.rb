class ChatMessage < ApplicationRecord
  belongs_to :chat_room
  belongs_to :customer
  belongs_to :community, optional: true

  has_one_attached :chat_image

  validates :content, presence: true
end
