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
  end
end
