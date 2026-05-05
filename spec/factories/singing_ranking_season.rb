FactoryBot.define do
  factory :singing_ranking_season do
    sequence(:name) { |n| "#{2026}年#{n}月シーズン" }
    starts_on { Date.current.beginning_of_month }
    ends_on   { Date.current.end_of_month }
    status    { "active" }
    season_type { "monthly" }

    trait :draft do
      status { "draft" }
    end

    trait :closed do
      status    { "closed" }
      starts_on { 1.month.ago.to_date.beginning_of_month }
      ends_on   { 1.month.ago.to_date.end_of_month }
    end

    trait :current do
      status    { "active" }
      starts_on { Date.current.beginning_of_month }
      ends_on   { Date.current.end_of_month }
    end

    trait :future do
      status    { "draft" }
      starts_on { 1.month.from_now.to_date.beginning_of_month }
      ends_on   { 1.month.from_now.to_date.end_of_month }
    end
  end
end
