FactoryBot.define do
  factory :event do
    sequence(:event_name) { |n| "event#{n}" }
    sequence(:event_start_time) { "Tue, 26 Sep 2023 18:28:26 +0900" }
    sequence(:event_end_time) { "Tue, 26 Sep 2023 19:28:26 +0900" }
    sequence(:entrance_fee) { 1500 }
    sequence(:place) { "MMMstudio" }
    sequence(:address) { |n| "埼玉県さいたま市#{n}" }
    sequence(:introduction) { |n| "introduction#{n}" }
    customer
    community
    trait :event_with_songs do
      after(:build) do |event|
        event.songs << build(:song)
      end
    end
  end
end