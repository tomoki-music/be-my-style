class AdminNotificationMailer < ApplicationMailer
  def paid_plan_subscribed
    @admin = params[:admin]
    @customer = params[:customer]
    @plan = params[:plan]
    @notification = params[:notification]
    @customer_url = edit_admin_customer_url(@customer)

    mail to: @admin.email, subject: "【BeMyStyle】有料プラン契約がありました（#{@plan.upcase}）"
  end

  def customer_feedback_created
    @admin = params[:admin]
    @feedback = params[:feedback]
    @customer = @feedback.customer
    @feedback_url = admin_customer_feedback_url(@feedback)

    mail to: @admin.email,
         subject: "【BeMyStyle】ご意見・ご相談BOXに新しい投稿がありました（#{@feedback.category_label}）"
  end
end
