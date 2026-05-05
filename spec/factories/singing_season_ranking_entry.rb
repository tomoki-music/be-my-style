FactoryBot.define do
  factory :singing_season_ranking_entry do
    association :singing_ranking_season
    association :customer, domain_name: "singing"
    rank     { 1 }
    score    { 80 }
    category { "overall" }
    title    { nil }
    badge_key { nil }
  end
end
