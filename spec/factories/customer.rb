FactoryBot.define do
  factory :customer do
    sequence(:name) { |n| "customer#{n}" }
    sequence(:email) { |n| "person#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
    trait :customer_with_parts do
      after(:build) do |customer|
        customer.parts << build(:part)
      end
    end
  end
end