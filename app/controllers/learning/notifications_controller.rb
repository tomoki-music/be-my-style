class Learning::NotificationsController < Learning::BaseController
  def index
    @notification_setting = Learning::NotificationSetting.effective_for(current_customer)
    @notifications = Learning::NotificationDispatcher.new(current_customer).preview
  end
end
