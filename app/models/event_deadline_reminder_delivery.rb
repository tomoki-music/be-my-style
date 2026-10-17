class EventDeadlineReminderDelivery < ApplicationRecord
  belongs_to :reminder, class_name: "EventDeadlineReminder", foreign_key: :event_deadline_reminder_id, inverse_of: :deliveries
  belongs_to :customer

  # sending: 送信直前に作成(この行がある受信者には二度と送らない)
  # delivered: 送信成功 / failed: 送信失敗・結果不明 / skipped: 直前確認で対象外・非本番で送信停止
  enum status: { sending: 0, delivered: 1, failed: 2, skipped: 3 }
end
