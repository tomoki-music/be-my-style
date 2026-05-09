class Learning::NotificationsController < Learning::BaseController
  def index
    @notification_setting = Learning::NotificationSetting.effective_for(current_customer)
    @notifications = notification_dispatcher.preview
    @notification_logs = current_customer.learning_notification_logs
      .includes(:learning_student)
      .order(generated_at: :desc, created_at: :desc)
      .limit(50)
  end

  def persist_preview
    saved_logs = notification_dispatcher.persist_preview!

    if saved_logs.any?
      redirect_to learning_notifications_path, notice: "今日の通知候補を履歴に保存しました。"
    else
      redirect_to learning_notifications_path, alert: "保存できる通知候補はありません。通知設定がOFFの場合は保存されません。"
    end
  end

  private

  def notification_dispatcher
    @notification_dispatcher ||= Learning::NotificationDispatcher.new(current_customer)
  end
end
