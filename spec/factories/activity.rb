FactoryBot.define do
  factory :activity do
    sequence(:title) { |n| "title#{n}" }
    sequence(:introduction) { |n| "introduction#{n}" }
    customer
  end
end