module EventDeadlineRemindersHelper
  WEEKDAYS = %w[日 月 火 水 木 金 土].freeze

  # 例: 2026年10月17日(土) 11:59
  def deadline_reminder_time(time)
    return if time.blank?

    time = time.in_time_zone(EventDeadlineReminder::TIME_ZONE)
    "#{time.year}年#{time.month}月#{time.day}日(#{WEEKDAYS[time.wday]}) #{time.strftime('%H:%M')}"
  end

  # 戻り値: { label:, modifier:, detail: }
  def deadline_reminder_status(reminder, now: Time.current)
    case reminder.status
    when "sent"
      return { label: "送信済み", modifier: "sent", detail: deadline_reminder_sent_detail(reminder) }
    when "failed"
      return { label: "失敗", modifier: "failed", detail: deadline_reminder_sent_detail(reminder) }
    when "sending"
      return { label: "送信中", modifier: "sending", detail: "送信処理を実行しています" }
    end

    return { label: "無効", modifier: "disabled", detail: nil } if !reminder.persisted? || !reminder.enabled?
    return { label: "締め切り未設定", modifier: "disabled", detail: "締め切りを設定すると有効にできます" } if reminder.deadline.blank?

    reason = EventDeadlineReminders::Eligibility.reason(reminder, now: now)
    case reason
    when nil, :before_schedule
      { label: "未送信（送信予定）", modifier: "pending", detail: nil }
    when :not_armed
      { label: "未送信（自動送信しません）", modifier: "warning", detail: deadline_reminder_disarm_detail(reminder) }
    else
      { label: "未送信", modifier: "warning", detail: EventDeadlineReminders::Eligibility::REASON_LABELS.fetch(reason) }
    end
  end

  def deadline_reminder_preview(reminder)
    return if reminder.deadline.blank? || !reminder.event&.persisted?

    sent_at = [reminder.scheduled_at, Time.current].max
    EventDeadlineReminders::MessageBuilder.call(event: reminder.event, kind: reminder.kind, sent_at: sent_at)
  end

  private

  def deadline_reminder_disarm_detail(reminder)
    if reminder.disarmed_by_deadline_changed_past?
      "締め切りの変更で送信予定日時が過去になったため、自動では送信しません。"
    else
      "送信予定日時を過ぎてから有効化されたため、自動では送信しません。"
    end
  end

  def deadline_reminder_sent_detail(reminder)
    parts = []
    parts << "#{deadline_reminder_time(reminder.sent_at)}（日本時間）" if reminder.sent_at.present?
    parts << "#{EventDeadlineReminder::CHANNEL_LABELS.fetch(reminder.sent_channel)}で送信" if reminder.sent_channel.present?
    if reminder.sent_via_mail?
      skipped = reminder.deliveries.skipped.count
      parts << "成功#{reminder.delivered_count}名・失敗#{reminder.failed_count}名・対象外#{skipped}名"
    end
    parts << "締め切り#{deadline_reminder_time(reminder.sent_for_deadline)}分" if reminder.sent_for_deadline.present?
    parts << reminder.failure_reason if reminder.failure_reason.present?
    parts.join(" / ")
  end
end
