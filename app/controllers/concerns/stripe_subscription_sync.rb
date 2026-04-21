module StripeSubscriptionSync
  extend ActiveSupport::Concern

  private

  def stripe_price_id_for(plan)
    prices = Rails.application.credentials.dig(:stripe, :price)
    env_key = Rails.env.production? ? :live : :test

    prices&.dig(plan.to_sym, env_key)
  end

  def detect_plan(price_id)
    prices = Rails.application.credentials.dig(:stripe, :price)

    case price_id
    when prices[:light][:test], prices[:light][:live]
      "light"
    when prices[:core][:test], prices[:core][:live]
      "core"
    when prices[:premium][:test], prices[:premium][:live]
      "premium"
    end
  end

  def retrieve_checkout_session(session_id)
    Stripe::Checkout::Session.retrieve(
      {
        id: session_id,
        expand: ["line_items"]
      }
    )
  end

  def sync_subscription_from_checkout_session!(customer, session_id)
    return false if customer.blank? || session_id.blank?

    session = retrieve_checkout_session(session_id)
    price_id = session.line_items.data[0]&.price&.id
    plan = detect_plan(price_id)

    return false if plan.blank? || session.subscription.blank? || session.customer.blank?

    record = Subscription.find_by(stripe_subscription_id: session.subscription) || customer.subscription || customer.build_subscription
    previous_plan = record.plan
    previous_status = record.status
    record.assign_attributes(
      stripe_customer_id: session.customer,
      stripe_subscription_id: session.subscription,
      status: "active",
      plan: plan
    )
    record.save!
    notify_admin_paid_plan_subscription!(
      customer: customer,
      plan: plan,
      stripe_subscription_id: session.subscription,
      previous_plan: previous_plan,
      previous_status: previous_status,
      current_status: record.status
    )
    true
  end

  def sync_subscription_from_stripe_subscription!(stripe_subscription)
    return false if stripe_subscription.blank?

    customer = Customer.joins(:subscription).find_by(subscriptions: { stripe_customer_id: stripe_subscription.customer })
    return false if customer.blank?

    price_id = stripe_subscription.items.data.first&.price&.id
    plan = detect_plan(price_id)
    return false if plan.blank?

    record = customer.subscription || customer.build_subscription
    previous_plan = record.plan
    previous_status = record.status
    record.assign_attributes(
      stripe_customer_id: stripe_subscription.customer,
      stripe_subscription_id: stripe_subscription.id,
      status: stripe_subscription.status,
      plan: plan
    )
    record.save!
    notify_admin_paid_plan_subscription!(
      customer: customer,
      plan: plan,
      stripe_subscription_id: stripe_subscription.id,
      previous_plan: previous_plan,
      previous_status: previous_status,
      current_status: record.status
    )
    true
  end

  def notify_admin_paid_plan_subscription!(customer:, plan:, stripe_subscription_id:, previous_plan:, previous_status:, current_status:)
    return unless current_status == "active"
    return unless %w[light core premium].include?(plan.to_s)

    was_active_paid_plan = previous_status == "active" && %w[light core premium].include?(previous_plan.to_s)
    return if was_active_paid_plan && previous_plan.to_s == plan.to_s

    AdminSubscriptionNotifier.notify_paid_plan_subscribed!(
      customer: customer,
      plan: plan,
      stripe_subscription_id: stripe_subscription_id
    )
  end
end
