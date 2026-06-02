class Singing::SessionsController < Public::SessionsController
  include DomainScopedSession
  include StripeSubscriptionSync

  domain_auth_for :singing

  def after_sign_in_path_for(resource)
    sync_pending_checkout_on_login(resource)
    super
  end

  private

  # Confirmable 環境でのメール確認後ログイン時に pending checkout を自動同期する。
  # customer_id で紐付け済みのレコード、または stripe_email が一致するレコードを対象にする。
  def sync_pending_checkout_on_login(customer)
    pending = PendingStripeCheckout.find_unprocessed_for_customer(customer)
    return unless pending

    if sync_subscription_from_checkout_session!(customer, pending.stripe_session_id)
      pending.update!(customer: customer, processed_at: Time.current)
      flash[:notice] = "プラン登録が完了しました！"
    end
  rescue => e
    Rails.logger.error("PendingStripeCheckout sync on login failed: #{e.message}")
  end
end
