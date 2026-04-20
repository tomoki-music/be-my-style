module NotificationsHelper
  def unchecked_notifications
    if current_customer.present?
      current_customer.passive_notifications.where(checked: false)
    end
  end

  def business_notification_path(notification)
    case notification.action
    when "like", "message"
      business_post_path(notification.post_id) if notification.post_id.present?
    when "request", "accept"
      business_community_path(notification.community_id) if notification.community_id.present?
    when "follow"
      business_customer_path(notification.visitor_id) if notification.visitor_id.present?
    when "project_created", "project_joined", "project_message"
      business_project_path(notification.project_id) if notification.project_id.present?
    end
  end
end
