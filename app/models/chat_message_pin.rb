class ChatMessagePin < ApplicationRecord
  belongs_to :chat_message
  belongs_to :pinned_by_customer, class_name: "Customer"
end
