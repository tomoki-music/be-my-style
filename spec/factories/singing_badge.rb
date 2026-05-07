FactoryBot.define do
  factory :singing_badge do
    association :customer, domain_name: "singing"
    association :singing_ranking_season
    badge_type  { "monthly_champion" }
    awarded_at  { Time.current }
  end
end
