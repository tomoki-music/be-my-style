FactoryBot.define do
  factory :song do
    sequence(:song_name) { |n| "song#{n}" }
    sequence(:youtube_url) { |n| "youtube_url#{n}" }
    sequence(:introduction) { |n| "introduction#{n}" }
    event
  end
end