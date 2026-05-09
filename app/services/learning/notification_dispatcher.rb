module Learning
  class NotificationDispatcher
    CHANNELS = %i[line email manual].freeze

    def initialize(customer, channels: [], line_adapter: LineNotificationAdapter.new)
      @customer = customer
      @channels = Array(channels).map(&:to_sym)
      @line_adapter = line_adapter
    end

    def preview
      return [] unless notification_setting.reminder_enabled?

      reminders
    end

    def persist_preview!
      return [] unless notification_setting.reminder_enabled?

      reminders.filter_map { |reminder| find_or_create_log(reminder) }
    end

    def dispatch
      return [] unless notification_setting.reminder_enabled?

      channels = (@channels.presence || [notification_setting.delivery_channel]).map(&:to_sym) & CHANNELS
      selected_channel = (channels.first || notification_setting.delivery_channel).to_s
      status = %w[email line].include?(selected_channel) ? "queued" : "skipped"

      persist_preview!.each do |log|
        log.update!(status: status, delivery_channel: selected_channel)
        @line_adapter.deliver(log) if selected_channel == "line"
        log
      end
    end

    private

    def reminders
      @reminders ||= ReminderService.for_customer(@customer)
    end

    def notification_setting
      @notification_setting ||= NotificationSetting.effective_for(@customer)
    end

    def find_or_create_log(reminder)
      existing_log = Learning::NotificationLog
        .where(
          customer: @customer,
          learning_student: reminder.student,
          notification_type: "reminder"
        )
        .where(generated_at: Time.zone.today.all_day)
        .first
      return existing_log if existing_log

      Learning::NotificationLog.create!(
        customer: @customer,
        learning_student: reminder.student,
        notification_type: "reminder",
        level: reminder.level,
        delivery_channel: notification_setting.delivery_channel,
        status: "previewed",
        title: "#{reminder.student.display_name}さんへの通知候補",
        message: reminder.message,
        recommended_action: reminder.recommended_action,
        generated_at: reminder.generated_at,
        metadata: {
          stage: reminder.stage,
          days_idle: reminder.days_idle,
          source: "Learning::ReminderService"
        }
      )
    end
  end
end
