class Learning::NotificationsController < Learning::BaseController
  def index
    @notifications = Learning::NotificationDispatcher.new(current_customer).preview
  end
end
