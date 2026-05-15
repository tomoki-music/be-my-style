FactoryBot.define do
  factory :singing_daily_challenge_progress do
    association :customer, domain_name: "singing"
    association :singing_daily_challenge
    completed_at { Time.current }
    xp_rewarded { singing_daily_challenge.xp_reward }
  end
end
