# app/controllers/public/stripe_controller.rb
class Public::StripeController < ApplicationController
  before_action :authenticate_customer!

  def create_checkout
    plan = params[:plan]

    price_id = case plan
    when "light"
      Rails.env.production? ? "price_1TNcFJFzjXRw4GqFwDLOlLcF" : "price_1TNcJeFzjXRw4GqF5uvUk00I"
    when "core"
      Rails.env.production? ? "price_1TNcGRFzjXRw4GqFEZD9xvv6" : "price_1TNcK3FzjXRw4GqFaCKKlZ79"
    when "premium"
      Rails.env.production? ? "price_1TNcH0FzjXRw4GqFpVuGN1cp" : "price_1TNcKPFzjXRw4GqFrOCiFEuR"
    end

    session = Stripe::Checkout::Session.create({
      customer_email: current_customer.email,
      payment_method_types: ['card'],
      line_items: [{
        price: price_id,
        quantity: 1,
      }],
      mode: 'subscription',
      success_url: root_url + "?success=true",
      cancel_url: root_url + "?canceled=true",
    })

    redirect_to session.url, allow_other_host: true
  end

  def portal
    unless current_customer.subscription&.stripe_customer_id
      return redirect_to root_path, alert: "サブスクが見つかりません"
    end

    session = Stripe::BillingPortal::Session.create({
      customer: current_customer.subscription.stripe_customer_id,
      return_url: root_url
    })

    redirect_to session.url, allow_other_host: true
  end

end