FactoryBot.define do
  factory :singing_daily_challenge do
    challenge_date { Date.current }
    challenge_type { "count" }
    target_attribute { "overall" }
    threshold_value { 1 }
    xp_reward { 20 }
    title { "今日1回診断してみよう！" }
    description { "1回でも診断を完了させよう。" }
  end
end
