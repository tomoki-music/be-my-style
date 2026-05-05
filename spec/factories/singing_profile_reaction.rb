FactoryBot.define do
  factory :singing_profile_reaction do
    association :customer, domain_name: "singing"
    association :target_customer, factory: :customer, domain_name: "singing"
    reaction_type { "cheer" }
  end
end
