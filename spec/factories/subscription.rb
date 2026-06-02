FactoryBot.define do
  factory :subscription do
    association :customer
    stripe_customer_id { "cus_test_#{SecureRandom.hex(8)}" }
    stripe_subscription_id { "sub_test_#{SecureRandom.hex(8)}" }
    status { "active" }
    plan { "light" }

    trait :free do
      stripe_customer_id { nil }
      stripe_subscription_id { nil }
      status { "free" }
      plan { "free" }
    end

    trait :canceled do
      status { "canceled" }
    end
  end
end
