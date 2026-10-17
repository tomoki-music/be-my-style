# frozen_string_literal: true

namespace :event_deadline_reminders do
  desc "締め切り自動リマインドの状態を表示する(読み取り専用。送信・DB更新は行わない)"
  task status: :environment do
    now = Time.current
    jst = ->(time) { time&.in_time_zone(EventDeadlineReminder::TIME_ZONE)&.strftime("%Y-%m-%d %H:%M") }
    stale_before = now - EventDeadlineReminder::STALE_SENDING_AFTER

    puts "[event_deadline_reminders:status] now=#{jst.call(now)} JST"
    puts "  enabled_by_status=#{EventDeadlineReminder.where(enabled: true).group(:status).count}"
    puts "  all_by_status=#{EventDeadlineReminder.group(:status).count}"

    armed = EventDeadlineReminder.includes(:event)
                                 .where(enabled: true, status: EventDeadlineReminder.statuses[:pending])
                                 .where("armed_deadline > ?", now)
                                 .order(:armed_deadline).to_a
    due = armed.select { |reminder| reminder.armed_scheduled_at <= now }
    puts "  due_now=#{due.size} (次回の定期実行で送信対象になりうる件数。送信時に再確認する)"
    due.each do |reminder|
      reason = EventDeadlineReminders::Eligibility.reason(reminder, now: now)
      puts "    reminder_id=#{reminder.id} event_id=#{reminder.event_id} kind=#{reminder.kind} channel=#{reminder.channel} " \
           "lead_hours=#{reminder.lead_hours} custom_message=#{reminder.custom_message?} " \
           "deadline=#{jst.call(reminder.deadline)} skip_reason=#{reason || 'none'}"
    end

    upcoming = armed.select { |reminder| reminder.armed_scheduled_at > now }.sort_by(&:armed_scheduled_at).first(20)
    puts "  upcoming=#{upcoming.size}(最大20件)"
    upcoming.each do |reminder|
      puts "    reminder_id=#{reminder.id} event_id=#{reminder.event_id} kind=#{reminder.kind} channel=#{reminder.channel} " \
           "lead_hours=#{reminder.lead_hours} armed_lead_hours=#{reminder.armed_lead_hours} " \
           "custom_message=#{reminder.custom_message?} scheduled_at=#{jst.call(reminder.armed_scheduled_at)}"
    end

    sending = EventDeadlineReminder.where(status: EventDeadlineReminder.statuses[:sending]).order(:started_at)
    puts "  sending=#{sending.size}"
    sending.each do |reminder|
      state = reminder.started_at && reminder.started_at < stale_before ? "STALE(次回の定期実行で引き継ぎ)" : "in_progress"
      puts "    reminder_id=#{reminder.id} event_id=#{reminder.event_id} started_at=#{jst.call(reminder.started_at)} #{state} " \
           "deliveries=#{reminder.deliveries.group(:status).count}"
    end

    failed = EventDeadlineReminder.where(status: EventDeadlineReminder.statuses[:failed]).order(updated_at: :desc).limit(20)
    puts "  failed=#{EventDeadlineReminder.failed.count}(最新20件を表示)"
    failed.each do |reminder|
      puts "    reminder_id=#{reminder.id} event_id=#{reminder.event_id} kind=#{reminder.kind} channel=#{reminder.channel} " \
           "at=#{jst.call(reminder.sent_at)} reason=#{reminder.failure_reason}"
    end

    failed_deliveries = EventDeadlineReminderDelivery.failed
    puts "  failed_deliveries=#{failed_deliveries.count} " \
         "not_sent=#{failed_deliveries.where('failure_reason LIKE ?', "#{EventDeadlineReminders::MailDeliverer::NOT_SENT_LABEL}%").count} " \
         "unknown=#{failed_deliveries.where('failure_reason LIKE ?', "#{EventDeadlineReminders::MailDeliverer::UNKNOWN_LABEL}%").count}"
    puts "[event_deadline_reminders:status] done"
  end
end
