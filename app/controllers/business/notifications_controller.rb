class Business::NotificationsController < ApplicationController
  def index

    @notifications =
      current_customer
      .passive_notifications
      .order(created_at: :desc)

    @notifications.update_all(checked: true)

  end
end
