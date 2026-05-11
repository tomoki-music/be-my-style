class Learning::AutoRemindersController < Learning::BaseController
  def index
    @notification_setting = Learning::NotificationSetting.effective_for(current_customer)
    @auto_reminder_service = Learning::AutoReminderService.new(current_customer, dry_run: true)
    @auto_reminder_results = @auto_reminder_service.call
    @auto_reminder_summary = @auto_reminder_service.summary
    connected_student_ids = current_customer.learning_line_connections.connected
      .where.not(learning_student_id: nil)
      .select(:learning_student_id)
    @line_unconnected_count = current_customer.learning_students.active
      .where.not(id: connected_student_ids)
      .count
    @auto_notification_logs = current_customer.learning_notification_logs
      .includes(:learning_student)
      .where(notification_type: Learning::NotificationLog::AUTO_REMINDER_TYPES)
      .order(generated_at: :desc, created_at: :desc)
      .limit(100)
  end
end
