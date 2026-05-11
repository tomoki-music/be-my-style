class AddAutoReminderSettingsToLearningNotificationSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :learning_notification_settings, :auto_reminder_enabled, :boolean, null: false, default: false
    add_column :learning_notification_settings, :auto_reminder_send_hour, :integer
  end
end
