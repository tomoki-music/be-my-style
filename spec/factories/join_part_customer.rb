FactoryBot.define do
  factory :join_part_customer do
    association :customer
    association :join_part
  end
end
