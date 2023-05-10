module NotificationsHelper
  def unchecked_notifications
    if current_customer.present?
      current_customer.passive_notifications.where(checked: false)
    end
  end
end
