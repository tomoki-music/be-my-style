FactoryBot.define do
  factory :chat_message_link_preview do
    chat_message
    provider { :youtube }
    url { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }
    external_id { "dQw4w9WgXcQ" }
    position { 0 }
    status { :pending }
  end
end
