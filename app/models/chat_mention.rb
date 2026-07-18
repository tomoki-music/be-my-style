class ChatMention < ApplicationRecord
  belongs_to :chat_message
  belongs_to :mentioned_customer, class_name: "Customer"
end
