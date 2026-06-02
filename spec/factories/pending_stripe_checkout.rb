FactoryBot.define do
  factory :pending_stripe_checkout do
    sequence(:stripe_session_id) { |n| "cs_test_pending_#{n}" }
    stripe_customer_id     { "cus_test_#{SecureRandom.hex(8)}" }
    stripe_subscription_id { "sub_test_#{SecureRandom.hex(8)}" }
    stripe_email           { "payer@example.com" }
    plan_key               { "light" }
    customer               { nil }
    processed_at           { nil }

    trait :processed do
      customer
      processed_at { 1.hour.ago }
    end

    trait :linked do
      association :customer
    end
  end
end
