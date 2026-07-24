FactoryBot.define do
  factory :chat_message_link_preview do
    chat_message
    provider { :youtube }
    url { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }
    external_id { "dQw4w9WgXcQ" }
    position { 0 }
    status { :pending }

    trait :event do
      provider { :event }
      url { "https://www.example.com/public/events/1" }
      external_id { "1" }
      status { :fetched }
      fetched_at { Time.current }
    end
  end
end
