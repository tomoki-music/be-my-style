FactoryBot.define do
  factory :community do
    sequence(:name) { |n| "community#{n}" }
    sequence(:introduction) { "楽しいコミュニティです！" }
    owner_id { 1 }
  end
end