class Public::NotificationsController < ApplicationController
  before_action :authenticate_customer!
  def index
    @notifications = current_customer.passive_notifications.page(params[:page]).per(20)
    @notifications.where(checked: false).each do |notification|
      notification.update_attribute(:checked, true)
    end
  end
end
