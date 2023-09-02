FactoryBot.define do
  factory :part do
    sequence(:name) { |n| "part-#{n}" }
  end
end