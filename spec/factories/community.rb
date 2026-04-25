FactoryBot.define do
  factory :community do
    sequence(:name) { |n| "community#{n}" }
    sequence(:introduction) { "楽しいコミュニティです！" }
    domain { Domain.find_or_create_by!(name: "music") }
    owner_id { 1 }
  end
end
