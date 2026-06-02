class Singing::CheckoutController < ApplicationController
  include StripeSubscriptionSync

  skip_before_action :authenticate_customer!

  ALLOWED_PLANS = %w[light core premium].freeze

  def redirect
    plan = params[:plan]

    unless ALLOWED_PLANS.include?(plan)
      redirect_to singing_root_path, alert: "無効なプランです。"
      return
    end

    # 既にStripe管理のサブスクがある有料ユーザーは二重契約防止のためPortalへ
    if customer_signed_in? && current_customer.stripe_managed_subscription?
      begin
        portal_session = Stripe::BillingPortal::Session.create({
          customer: current_customer.subscription.stripe_customer_id,
          return_url: singing_root_url
        })
        redirect_to portal_session.url, allow_other_host: true
      rescue Stripe::StripeError => e
        Rails.logger.error("LP Checkout portal redirect failed: #{e.message}")
        redirect_to singing_root_path, alert: "プラン変更ページへの遷移に失敗しました。しばらくしてから再度お試しください。"
      end
      return
    end

    price_id = stripe_price_id_for(plan)

    unless price_id
      redirect_to singing_root_path, alert: "選択したプランが見つかりません。"
      return
    end

    checkout_params = {
      payment_method_types: ['card'],
      line_items: [{ price: price_id, quantity: 1 }],
      mode: 'subscription',
      success_url: "#{singing_checkout_success_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: lp_cancel_url,
      allow_promotion_codes: true,
      metadata: { plan_key: plan }
    }

    checkout_params[:customer_email] = current_customer.email if customer_signed_in?

    stripe_session = Stripe::Checkout::Session.create(checkout_params)
    redirect_to stripe_session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error("LP Checkout redirect failed: #{e.message}")
    redirect_to singing_root_path, alert: "決済ページへの遷移に失敗しました。しばらくしてから再度お試しください。"
  end

  def success
    session_id = params[:session_id]
    log_checkout_success_attempt(session_id)

    if customer_signed_in?
      if sync_subscription_from_checkout_session!(current_customer, session_id)
        redirect_to singing_root_path, notice: "プラン登録が完了しました！"
      else
        redirect_to singing_root_path, alert: "プランの反映を確認できませんでした。しばらくしてからご確認ください。"
      end
    else
      persist_pending_checkout(session_id)
      redirect_to new_singing_customer_registration_path,
        notice: "お支払いが完了しました！アカウントを作成してプランを有効にしてください。"
    end
  rescue Stripe::InvalidRequestError => e
    Rails.logger.error("LP Checkout success sync failed: #{e.message}")
    session[:pending_stripe_session_id] = params[:session_id] unless customer_signed_in?
    redirect_to new_singing_customer_registration_path,
      notice: "お支払いが完了しました。アカウントを作成してプランを有効にしてください。"
  end

  private

  def persist_pending_checkout(session_id)
    session[:pending_stripe_session_id] = session_id

    stripe_session = retrieve_checkout_session(session_id)
    PendingStripeCheckout.create_or_find_by!(stripe_session_id: session_id) do |r|
      r.stripe_customer_id     = stripe_session.customer
      r.stripe_subscription_id = stripe_session.subscription
      r.stripe_email           = stripe_session.customer_details&.email
      r.plan_key               = stripe_session.metadata&.[]("plan_key")
    end
  rescue => e
    Rails.logger.warn("PendingStripeCheckout persist failed (non-fatal): #{e.message}")
  end

  def lp_cancel_url
    Rails.application.credentials.dig(:singing_lp_cancel_url).presence ||
      ENV.fetch("SINGING_LP_CANCEL_URL", new_singing_customer_registration_url)
  end

  def log_checkout_success_attempt(session_id)
    stripe_session = retrieve_checkout_session(session_id)
    Rails.logger.info(
      "LP Checkout success: session_id=#{session_id} " \
      "stripe_customer=#{stripe_session.customer} " \
      "email=#{stripe_session.customer_details&.email} " \
      "plan=#{stripe_session.metadata&.[]('plan_key')} " \
      "customer_signed_in=#{customer_signed_in?}"
    )
  rescue => e
    Rails.logger.warn("LP Checkout success log failed (non-fatal): #{e.message}")
  end
end
