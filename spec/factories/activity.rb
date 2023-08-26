FactoryBot.define do
  factory :activity do
    sequence(:title) { |n| "title#{n}" }
    sequence(:keep) { |n| "keep#{n}" }
    sequence(:problem) { |n| "problem#{n}" }
    sequence(:try) { |n| "try#{n}" }
    sequence(:introduction) { |n| "introduction#{n}" }
    customer
  end
end