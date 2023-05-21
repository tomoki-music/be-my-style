FactoryBot.define do
  factory :customer do
    sequence(:name) { |n| "customer#{n}" }
    sequence(:email) { |n| "person#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
  end
end