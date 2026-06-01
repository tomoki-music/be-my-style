FactoryBot.define do
  factory :singing_cheer_reaction do
    association :customer,        factory: :customer, domain_name: "singing"
    association :target_customer, factory: :customer, domain_name: "singing"
    reaction_type { "fire" }
  end
end
