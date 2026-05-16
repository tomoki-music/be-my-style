FactoryBot.define do
  factory :singing_achievement_badge do
    association :customer, domain_name: "singing"
    badge_key  { "first_diagnosis" }
    earned_at  { Time.current }
    metadata   { { schema_version: 1, badge_key: "first_diagnosis", badge_label: "First Note", earned_at_label: "2024年5月1日", diagnosis_count: 1 } }

    trait :first_diagnosis do
      badge_key { "first_diagnosis" }
    end

    trait :personal_best do
      badge_key { "personal_best" }
      metadata  { { schema_version: 1, badge_key: "personal_best", badge_label: "Personal Best", earned_at_label: "2024年5月1日", diagnosis_count: 5, current_best_score: 85, previous_best_score: 80, score_delta: 5, overall_score: 85 } }
    end

    trait :streak_7 do
      badge_key { "streak_7" }
      metadata  { { schema_version: 1, badge_key: "streak_7", badge_label: "7 Day Streak", earned_at_label: "2024年5月7日", diagnosis_count: 7, streak_days: 7 } }
    end

    trait :streak_30 do
      badge_key { "streak_30" }
      metadata  { { schema_version: 1, badge_key: "streak_30", badge_label: "Monthly Devotee", earned_at_label: "2024年5月30日", diagnosis_count: 30, streak_days: 30 } }
    end

    trait :first_score_90 do
      badge_key { "first_score_90" }
      metadata  { { schema_version: 1, badge_key: "first_score_90", badge_label: "Score 90 Club", earned_at_label: "2024年5月1日", diagnosis_count: 10, overall_score: 91 } }
    end

    trait :first_ranking do
      badge_key { "first_ranking" }
      metadata  { { schema_version: 1, badge_key: "first_ranking", badge_label: "First Entry", earned_at_label: "2024年5月1日", diagnosis_count: 3 } }
    end

    trait :diagnosis_10 do
      badge_key { "diagnosis_10" }
      metadata  { { schema_version: 1, badge_key: "diagnosis_10", badge_label: "10 Songs", earned_at_label: "2024年5月10日", diagnosis_count: 10 } }
    end

    trait :growth_10 do
      badge_key { "growth_10" }
      metadata  { { schema_version: 1, badge_key: "growth_10", badge_label: "Rising Star", earned_at_label: "2024年5月1日", diagnosis_count: 5, first_overall_score: 60, current_overall_score: 72, growth_delta: 12 } }
    end
  end
end
