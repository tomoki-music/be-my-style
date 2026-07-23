FactoryBot.define do
  factory :chat_message_pin do
    chat_message
    pinned_by_customer factory: :customer
  end
end
