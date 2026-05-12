FactoryBot.define do
  factory :community do
    sequence(:name) { |n| "community#{n}" }
    sequence(:introduction) { "楽しいコミュニティです！" }
    domain { Domain.find_or_create_by!(name: "music") }
    owner_id { 1 }
    required_plan_for_event_creation { "core" }

    trait :premium_origin do
      required_plan_for_event_creation { "premium" }
    end
  end
end
