FactoryBot.define do
  factory :singing_recap_movie_batch_execution do
    association :admin
    year                    { Time.current.year }
    target_customers_count  { 10 }
    new_movies_count        { 7 }
    regenerate_movies_count { 2 }
    skipped_movies_count    { 1 }
    skipped_breakdown       { { "pending" => 1, "processing" => 0, "completed" => 0 } }
    status                  { :enqueued }
    enqueued_at             { Time.current }
    total_movies_count      { 0 }
    completed_movies_count  { 0 }
    failed_movies_count     { 0 }
    started_at              { nil }
    finished_at             { nil }

    trait :running do
      status       { :running }
      started_at   { 1.minute.ago }
      total_movies_count { 10 }
    end

    trait :completed do
      status               { :completed }
      started_at           { 2.minutes.ago }
      finished_at          { Time.current }
      total_movies_count   { 10 }
      completed_movies_count { 9 }
      failed_movies_count  { 1 }
    end

    trait :failed do
      status      { :failed }
      started_at  { 1.minute.ago }
      finished_at { Time.current }
    end
  end
end
