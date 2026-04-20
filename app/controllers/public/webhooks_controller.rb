# app/controllers/public/webhooks_controller.rb
class Public::WebhooksController < ApplicationController
  include StripeSubscriptionSync

  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_customer!, raise: false
  skip_before_action :set_current_domain, raise: false

  def stripe
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']

    endpoint_secret = webhook_secret

    begin
      event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError
      return head :bad_request
    rescue Stripe::SignatureVerificationError
      return head :bad_request
    end

    case event.type
    when 'checkout.session.completed'
      handle_checkout_completed(event)
    when 'customer.subscription.created', 'customer.subscription.updated'
      handle_subscription_updated(event)
    when 'customer.subscription.deleted'
      handle_subscription_deleted(event)
    else
      Rails.logger.info("ℹ️ Unhandled event: #{event.type}")
    end

    head :ok
  end

  private

  # =========================
  # Checkout完了処理
  # =========================
  def handle_checkout_completed(event)
    session = event.data.object
    email = session.customer_details&.email
    Rails.logger.info("🔥 email: #{email}")

    return unless email

    customer = Customer.find_by(email: email)

    unless customer
      Rails.logger.error("❌ customer not found: #{email}")
      return
    end

    sync_subscription_from_checkout_session!(customer, session.id)
  end

  # =========================
  # 解約処理
  # =========================
  def handle_subscription_deleted(event)
    sub = event.data.object

    subscription = Subscription.find_by(stripe_subscription_id: sub.id)

    if subscription
      subscription.update(status: 'canceled')
    else
      Rails.logger.warn("⚠️ subscription not found: #{sub.id}")
    end
  end

  def handle_subscription_updated(event)
    sub = event.data.object

    unless sync_subscription_from_stripe_subscription!(sub)
      Rails.logger.warn("⚠️ subscription update sync skipped: #{sub.id}")
    end
  end
  # =========================
  # Webhook secret切替
  # =========================
  def webhook_secret
    if Rails.env.production?
      Rails.application.credentials.dig(:stripe, :live_webhook_secret)
    else
      Rails.application.credentials.dig(:stripe, :test_webhook_secret)
    end
  end
end
