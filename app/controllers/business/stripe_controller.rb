class Business::StripeController < ApplicationController
  include StripeSubscriptionSync

  before_action :authenticate_customer!

  def create_checkout
    current_customer.clear_stale_subscription!

    if current_customer.stripe_managed_subscription?
      redirect_to edit_business_customer_path(current_customer),
        alert: "現在契約中のプラン変更・キャンセルはStripeの管理画面から行えます。"
      return
    end

    price_id = stripe_price_id_for(params[:plan])

    unless price_id
      redirect_to business_root_path(anchor: "business-pricing"), alert: "選択したプランが見つかりません。"
      return
    end

    session = Stripe::Checkout::Session.create(
      customer_email: current_customer.email,
      payment_method_types: ["card"],
      line_items: [
        {
          price: price_id,
          quantity: 1
        }
      ],
      mode: "subscription",
      success_url: business_success_stripe_url(session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: business_root_url(canceled: true)
    )

    redirect_to session.url, allow_other_host: true
  end

  def success
    if sync_subscription_from_checkout_session!(current_customer, params[:session_id])
      redirect_to business_root_path(anchor: "business-pricing"), notice: "プラン登録が完了しました。"
    else
      redirect_to business_root_path(anchor: "business-pricing"), alert: "プランの反映を確認できませんでした。しばらくしてから再度ご確認ください。"
    end
  rescue Stripe::InvalidRequestError => e
    Rails.logger.error("Stripe checkout sync failed: #{e.message}")
    redirect_to business_root_path(anchor: "business-pricing"), alert: "プラン反映時にエラーが発生しました。"
  end

  def portal
    unless current_customer.stripe_managed_subscription?
      redirect_to business_root_path(anchor: "business-pricing"), alert: "Stripe連携されたサブスクが見つかりません。もう一度プラン登録をお試しください。"
      return
    end

    session = Stripe::BillingPortal::Session.create(
      customer: current_customer.subscription.stripe_customer_id,
      return_url: business_root_url
    )

    redirect_to session.url, allow_other_host: true
  end
end
