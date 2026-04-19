# config/initializers/stripe.rb
Stripe.api_key = if Rails.env.production?
  Rails.application.credentials.dig(:stripe, :live_secret_key)
else
  Rails.application.credentials.dig(:stripe, :test_secret_key)
end