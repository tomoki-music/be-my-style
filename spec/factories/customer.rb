FactoryBot.define do
  factory :customer do
    name { 'customer' }
    email { Faker::Internet.email }
    password { 'password' }
    password_confirmation { 'password' }
  end
end