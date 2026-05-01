FactoryBot.define do
  factory :activity_reaction do
    customer
    activity
    reaction_type { "fire" }
  end
end
