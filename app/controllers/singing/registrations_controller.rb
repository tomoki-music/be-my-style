class Singing::RegistrationsController < Public::RegistrationsController
  include DomainScopedRegistration
  include StripeSubscriptionSync

  domain_auth_for :singing

  protected

  # Confirmable が無効 or テスト環境でモック済みの場合に呼ばれる（即ログイン）
  def after_sign_up_path_for(resource)
    if (session_id = session.delete(:pending_stripe_session_id)).present?
      begin
        stripe_session = Stripe::Checkout::Session.retrieve(session_id)
        stripe_email = stripe_session.customer_details&.email

        if stripe_email.present? && stripe_email.downcase != resource.email.downcase
          Rails.logger.warn(
            "[Singing::Checkout] Stripe email mismatch. " \
            "session_id=#{session_id}, " \
            "stripe_email=#{stripe_email}, " \
            "registered_email=#{resource.email}, " \
            "stripe_customer_id=#{stripe_session.customer}, " \
            "plan_key=#{stripe_session.metadata&.[]("plan_key")}"
          )
          flash[:alert] = pending_checkout_email_mismatch_message
        else
          sync_subscription_from_checkout_session!(resource, session_id)
          mark_pending_checkout_processed!(resource, session_id)
        end
      rescue => e
        Rails.logger.error("Post-registration Stripe sync failed: #{e.message}")
      end
    end

    super
  end

  # Confirmable が有効で即ログインできない場合に呼ばれる
  # → DB の PendingStripeCheckout に customer を紐付けておき、
  #    メール確認後のログイン時に SessionsController で同期する
  def after_inactive_sign_up_path_for(resource)
    if (session_id = session.delete(:pending_stripe_session_id)).present?
      link_pending_checkout_to_customer(resource, session_id)
    end
    super
  end

  private

  def link_pending_checkout_to_customer(resource, session_id)
    pending = PendingStripeCheckout.find_by(stripe_session_id: session_id, processed_at: nil)
    return unless pending

    if pending.stripe_email.present? && pending.stripe_email.downcase != resource.email.downcase
      Rails.logger.warn(
        "[Singing::Checkout] Stripe email mismatch at inactive signup. " \
        "session_id=#{session_id}, " \
        "stripe_email=#{pending.stripe_email}, " \
        "registered_email=#{resource.email}"
      )
      flash[:alert] = pending_checkout_email_mismatch_message
      return
    end

    pending.update!(customer: resource)
  rescue => e
    Rails.logger.error("PendingStripeCheckout link on inactive signup failed: #{e.message}")
  end

  def mark_pending_checkout_processed!(customer, session_id)
    pending = PendingStripeCheckout.find_by(stripe_session_id: session_id)
    pending&.update!(customer: customer, processed_at: Time.current)
  rescue => e
    Rails.logger.warn("PendingStripeCheckout mark processed failed (non-fatal): #{e.message}")
  end

  def pending_checkout_email_mismatch_message
    "決済時のメールアドレスと登録メールアドレスが異なるため、" \
    "自動でプランを反映できませんでした。" \
    "お手数ですがお問い合わせください。" \
    "お問い合わせ先：i.tomoki0218@gmail.com"
  end
end
