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
    retry_status   { "pending" }
    retried_at     { nil }
    retried_by_id  { nil }
    retry_error_message { nil }
    auto_retry_status         { "not_applicable" }
    auto_retry_attempts_count { 0 }
    next_auto_retry_at        { nil }
    last_auto_retry_at        { nil }
    auto_retry_error_message  { nil }

    trait :with_recap_movie do
      association :recap_movie, factory: :singing_generated_recap_movie
    end

    trait :retried do
      retry_status { "retried" }
      retried_at   { Time.current }
    end

    trait :skipped do
      retry_status        { "skipped" }
      retry_error_message { "同一年のbatch実行中のためskip" }
    end

    trait :retry_failed do
      retry_status        { "retry_failed" }
      retry_error_message { "Unexpected error during retry" }
    end

    trait :resolved do
      retry_status      { "resolved" }
      retried_at        { Time.current - 1.hour }
      resolved_at       { Time.current }
      association :resolved_movie, factory: :singing_generated_recap_movie
    end

    trait :auto_retry_scheduled do
      auto_retry_status  { "scheduled" }
      next_auto_retry_at { 5.minutes.from_now }
    end

    trait :auto_retry_due do
      auto_retry_status  { "scheduled" }
      next_auto_retry_at { 1.minute.ago }
    end

    trait :auto_retry_running do
      auto_retry_status         { "running" }
      auto_retry_attempts_count { 1 }
      last_auto_retry_at        { Time.current }
    end

    trait :auto_retry_exhausted do
      auto_retry_status         { "exhausted" }
      auto_retry_attempts_count { 3 }
      last_auto_retry_at        { 1.hour.ago }
      auto_retry_error_message  { "Max attempts reached" }
    end

    trait :timeout_error do
      error_class   { "Timeout::Error" }
      error_message { "execution expired (timeout)" }
    end
  end
end
