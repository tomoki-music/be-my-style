FactoryBot.define do
  factory :event do
    date = DateTime.now
    sequence(:event_name) { |n| "event#{n}" }
    sequence(:event_date) { date }
    sequence(:entrance_fee) { 1500 }
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