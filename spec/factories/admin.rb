FactoryBot.define do
  factory :admin do
    sequence(:name) { |n| "admin#{n}" }
    sequence(:email) { |n| "admin#{n}@example.com" }
    password { 'admin-password' }
    password_confirmation { 'admin-password' }
  end
end