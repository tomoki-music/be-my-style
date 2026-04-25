FactoryBot.define do
  factory :customer do
    sequence(:name) { |n| "customer#{n}" }
    sequence(:email) { |n| "person#{n}@example.com" }
    domain_name { "music" }
    password { 'password' }
    password_confirmation { 'password' }

    after(:create) do |customer|
      domain = Domain.find_or_create_by!(name: customer.normalized_domain_name || Customer::DEFAULT_SIGN_UP_DOMAIN)
      CustomerDomain.find_or_create_by!(customer: customer, domain: domain)
    end

    trait :customer_with_parts do
      after(:build) do |customer|
        customer.parts << build(:part)
      end
    end
  end
end
