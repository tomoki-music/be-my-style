FactoryBot.define do
  factory :customer do
    name { 'customer' }
    sequence(:email) { |n| "person#{n}@example.com" }
    password { 'password' }
    password_confirmation { 'password' }
  end
end