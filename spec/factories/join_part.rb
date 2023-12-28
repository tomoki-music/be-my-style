FactoryBot.define do
  factory :join_part do
    sequence(:join_part_name) { |n| "join_part#{n}" }
    song
  end
end