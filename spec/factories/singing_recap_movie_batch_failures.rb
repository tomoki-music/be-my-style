FactoryBot.define do
  factory :singing_recap_movie_batch_failure do
    association :singing_recap_movie_batch_execution
    association :customer
    year        { Time.current.year }
    recap_movie_id { nil }
    error_class    { "StandardError" }
    error_message  { "Something went wrong" }
    backtrace_excerpt { "app/jobs/singing/generate_yearly_recap_movies_job.rb:38:in `block in perform'" }
    failed_at      { Time.current }
    metadata       { nil }

    trait :with_recap_movie do
      association :recap_movie, factory: :singing_generated_recap_movie
    end
  end
end
