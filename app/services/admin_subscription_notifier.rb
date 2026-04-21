class AdminSubscriptionNotifier
  PAID_PLANS = %w[light core premium].freeze
  ACTION = "paid_plan_subscribed".freeze

  def self.notify_paid_plan_subscribed!(customer:, plan:, stripe_subscription_id:)
    return unless customer.present?
    return unless PAID_PLANS.include?(plan.to_s)

    Admin.find_each do |admin|
      notification = admin.admin_notifications.build(
        customer: customer,
        action: ACTION,
        plan: plan,
        stripe_subscription_id: stripe_subscription_id
      )

      notification.message = "#{customer.name.presence || customer.email}さんが#{plan.upcase}プランを契約しました。"
      notification.save!

      AdminNotificationMailer.with(
        admin: admin,
        customer: customer,
        plan: plan,
        notification: notification
      ).paid_plan_subscribed.deliver_later
    end
  end
end
