FactoryBot.define do
  factory :customer_part do
    association :customer
    association :part
  end
end