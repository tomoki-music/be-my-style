class EventDeadlineReminderMailer < ApplicationMailer
  # 締め切り自動リマインド。1通=1受信者(To に複数人を入れない・CC/BCC を使わない)。
  # 件名・本文は EventDeadlineReminders::MessageBuilder の結果をそのまま使う。
  def remind
    @delivery = params[:delivery]
    @message = params[:message]
    @recipient = @delivery.customer
    @event = @delivery.reminder.event
    routes = Rails.application.routes.url_helpers
    @event_url = EventDeadlineReminders::MessageBuilder::BASE_URL + routes.public_event_path(@event)
    @mypage = EventDeadlineReminders::MessageBuilder::BASE_URL + routes.public_customer_path(@recipient)

    mail(to: @recipient.email, subject: "【BeMyStyle】#{@message.subject}")
  end
end
