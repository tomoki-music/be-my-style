class AddLeadHoursAndCustomMessageToEventDeadlineReminders < ActiveRecord::Migration[6.1]
  class MigrationReminder < ActiveRecord::Base
    self.table_name = "event_deadline_reminders"
  end

  def up
    # 締め切りの何時間前に送るか。既存行は従来どおり12時間として引き継ぐ。
    add_column :event_deadline_reminders, :lead_hours, :integer, null: false, default: 12
    # 主催者が編集した本文(空なら自動生成)。
    add_column :event_deadline_reminders, :custom_message, :text
    # 送信してよい送信予定日時。armed_deadline と組で記録し、締め切り・送信時間の
    # どちらかが変わって一致しなくなったら自動では送らない。
    add_column :event_deadline_reminders, :armed_scheduled_at, :datetime
    # 配信開始時に確定した件名・本文・配信方法(JSON)。送信中に設定が変わっても受信者ごとに混在させない。
    add_column :event_deadline_reminders, :message_snapshot, :text

    # 有効・無効・送信状態は変えず、送信待ちの行だけ従来の「締め切り-12時間」を記録する。
    MigrationReminder.reset_column_information
    MigrationReminder.where.not(armed_deadline: nil).find_each do |reminder|
      reminder.update_columns(armed_scheduled_at: reminder.armed_deadline - 12.hours)
    end
  end

  def down
    remove_column :event_deadline_reminders, :message_snapshot
    remove_column :event_deadline_reminders, :armed_scheduled_at
    remove_column :event_deadline_reminders, :custom_message
    remove_column :event_deadline_reminders, :lead_hours
  end
end
