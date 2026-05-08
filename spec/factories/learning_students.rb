FactoryBot.define do
  factory :learning_student do
    customer
    sequence(:name) { |n| "生徒#{n}" }
    main_part { "guitar" }
    status { "active" }
    total_effort_points { 0 }
    tutorial_completed { false }

    trait :with_nickname do
      nickname { "ギター君" }
    end

    trait :tutorial_done do
      tutorial_completed { true }
    end

    trait :in_group do
      association :learning_school_group
    end
  end

  factory :learning_school_group do
    customer
    sequence(:name) { |n| "○○高校#{n}" }
  end

  factory :learning_effort_point do
    customer
    learning_student
    point_type { "progress_log" }
    points { 5 }
    description { "練習記録: コード練習" }
    earned_on { Date.current }
  end

  factory :learning_portal_access do
    learning_student
    accessed_on { Date.current }
    streak_count { 1 }
  end

  factory :learning_progress_log do
    customer
    learning_student
    part { "guitar" }
    training_title { "コード練習" }
    practiced_on { Date.current }
    achievement_mark { "triangle" }
  end

  factory :learning_student_training do
    customer
    learning_student
    part { "guitar" }
    period { "1-2ヶ月" }
    level { "基礎" }
    title { "コード練習" }
    description { "Cコードを正確に押さえる" }
    status { "not_started" }
    achievement_mark { "cross" }
  end
end
