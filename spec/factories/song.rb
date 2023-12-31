FactoryBot.define do
  factory :song do
    sequence(:song_name) { |n| "song#{n}" }
    sequence(:youtube_url) { |n| "youtube_url#{n}" }
    sequence(:introduction) { |n| "introduction#{n}" }
    event
    after(:build) do |song|
      song.join_parts.each do |join_part|
        join_part.customers << customer
      end
    end
  end
end