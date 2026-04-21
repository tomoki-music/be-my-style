class AdminNotificationMailer < ApplicationMailer
  def paid_plan_subscribed
    @admin = params[:admin]
    @customer = params[:customer]
    @plan = params[:plan]
    @notification = params[:notification]
    @customer_url = edit_admin_customer_url(@customer)

    mail to: @admin.email, subject: "【BeMyStyle】有料プラン契約がありました（#{@plan.upcase}）"
  end
end
