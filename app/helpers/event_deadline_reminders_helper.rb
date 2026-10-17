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
      if reminder.started_at.present? && reminder.started_at < now - EventDeadlineReminder::STALE_SENDING_AFTER
        return { label: "送信中（停止の可能性）", modifier: "warning",
                 detail: "送信処理が止まっている可能性があります。次回の定期実行で引き継ぎ、結果不明の宛先には再送しません" }
      end

      return { label: "送信中", modifier: "sending", detail: "送信処理を実行しています" }
    end

    return { label: "無効", modifier: "disabled", detail: nil } unless reminder.enabled?
    return { label: "締め切り未設定", modifier: "disabled", detail: "締め切りを設定すると有効にできます" } if reminder.deadline.blank?
    if reminder.scheduled_at.blank?
      return { label: "送信タイミングを確認してください", modifier: "warning", detail: "1〜168の整数（時間）で入力してください" }
    end

    reason = EventDeadlineReminders::Eligibility.reason(reminder, now: now)
    case reason
    when :before_schedule
      { label: "未送信（送信予定）", modifier: "pending", detail: nil }
    when nil
      { label: "未送信（送信予定）", modifier: "pending",
        detail: "送信予定日時を過ぎています。締め切り前の次回の定期実行（5分ごと）で送信します" }
    when :not_armed
      { label: "未送信（自動送信しません）", modifier: "warning", detail: deadline_reminder_disarm_detail(reminder) }
    else
      { label: "未送信", modifier: "warning", detail: EventDeadlineReminders::Eligibility::REASON_LABELS.fetch(reason) }
    end
  end

  def deadline_reminder_lead_hours_options
    { min: EventDeadlineReminder::LEAD_HOURS_RANGE.min, max: EventDeadlineReminder::LEAD_HOURS_RANGE.max, step: 1 }
  end

  # 送信中・送信済み・失敗のときに、設定を変えても今回の通知に反映されないことを示す文言。
  def deadline_reminder_locked_note(reminder)
    case reminder.status
    when "sending"
      "送信中のため、送信タイミング・配信方法・メッセージは変更できません。送信は開始時に確定した内容で続けます。"
    when "sent", "failed"
      "この締め切りの通知は#{reminder.sent? ? '送信済み' : '失敗として確定済み'}のため、送信タイミングやメッセージを変更しても再送されません。"
    end
  end

  private

  def deadline_reminder_disarm_detail(reminder)
    if reminder.disarmed_by_deadline_changed_past?
      "送信予定日時を過ぎているため、自動送信されません（締め切りの変更で送信予定日時が過去になりました）。"
    elsif reminder.disarmed_by_lead_time_changed_past?
      "送信予定日時を過ぎているため、自動送信されません（送信タイミングの変更で送信予定日時が過去になりました）。"
    else
      "送信予定日時を過ぎているため、自動送信されません（送信予定日時を過ぎてから有効化されました）。"
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
    if reminder.message_snapshot.present?
      parts << "#{reminder.message_snapshot['lead_hours']}時間前の設定・#{reminder.message_snapshot['custom'] ? '編集した本文' : '自動生成の本文'}"
    end
    parts << reminder.failure_reason if reminder.failure_reason.present?
    parts.join(" / ")
  end
end
