FactoryBot.define do
  factory :singing_ai_challenge_progress do
    association :customer, domain_name: "singing"
    target_key { "rhythm" }
    challenge_month { Time.current.to_date.beginning_of_month }
    tried { false }
    completed { false }
    next_diagnosis_planned { false }
  end
end
