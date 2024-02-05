FactoryBot.define do
  factory :song do
    sequence(:song_name) { |n| "song#{n}" }
    sequence(:youtube_url) { |n| "youtube_url#{n}" }
    sequence(:introduction) { |n| "introduction#{n}" }
    event
    trait :song_with_parts do
      after(:build) do |song|
        song.join_parts << build(:join_part)
      end
    end
  end
end