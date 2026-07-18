FactoryBot.define do
  factory :chat_mention do
    chat_message
    mentioned_customer factory: :customer
  end
end
