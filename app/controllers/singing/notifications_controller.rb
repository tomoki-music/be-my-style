class Singing::NotificationsController < Singing::BaseController
  def index
    @notifications = current_customer.passive_notifications.page(params[:page]).per(10)
    @notifications.where(checked: false).update_all(checked: true)
  end
end
