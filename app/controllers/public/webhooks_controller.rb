# app/controllers/public/webhooks_controller.rb
class Public::WebhooksController < ApplicationController
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

    # 🔥 line_itemsを確実に取得（最重要）
    session = Stripe::Checkout::Session.retrieve(
      {
        id: session.id,
        expand: ['line_items']
      }
    )

    price_id = session.line_items.data[0].price.id
    email = session.customer_details&.email

    Rails.logger.info("🔥 price_id: #{price_id}")
    Rails.logger.info("🔥 email: #{email}")

    return unless email

    customer = Customer.find_by(email: email)

    unless customer
      Rails.logger.error("❌ customer not found: #{email}")
      return
    end

    plan = detect_plan(price_id)

    Rails.logger.info("🔥 plan: #{plan}")

    # 🔥 二重登録防止
    return if Subscription.exists?(stripe_subscription_id: session.subscription)

    Subscription.create!(
      customer: customer,
      stripe_customer_id: session.customer,
      stripe_subscription_id: session.subscription,
      status: 'active',
      plan: plan
    )
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

  # =========================
  # プラン判定
  # =========================
  def detect_plan(price_id)
    prices = Rails.application.credentials.dig(:stripe, :price)

    case price_id
    when prices[:light][:test], prices[:light][:live]
      "light"
    when prices[:core][:test], prices[:core][:live]
      "core"
    when prices[:premium][:test], prices[:premium][:live]
      "premium"
    else
      Rails.logger.error("❌ unknown price_id: #{price_id}")
      "unknown"
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