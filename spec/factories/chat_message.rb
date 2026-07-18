FactoryBot.define do
  factory :chat_message do
    content { 'お元気ですか？' }

    trait :markdown do
      content_format { :markdown }
    end
  end
end