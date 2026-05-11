module Learning
  class NotificationLog < ApplicationRecord
    self.table_name = "learning_notification_logs"

    NOTIFICATION_TYPES = %w[
      reminder
      teacher_action
      teacher_message
      teacher_bulk_message
      followup_message
      assignment_created
      auto_inactive_reminder
      auto_assignment_due_reminder
      auto_assignment_overdue_reminder
      teacher_revision_request
      weekly_summary
      student_reactivation
    ].freeze

    AUTO_REMINDER_TYPES = %w[
      auto_inactive_reminder
      auto_assignment_due_reminder
      auto_assignment_overdue_reminder
    ].freeze

    LEVELS = %w[light normal strong info].freeze
    DELIVERY_CHANNELS = %w[manual email line].freeze
    STATUSES = %w[previewed queued sent failed skipped].freeze
    DUPLICATE_RECENTLY_SENT_MESSAGE = "duplicate_recently_sent".freeze

    belongs_to :customer
    belongs_to :learning_student, class_name: "LearningStudent", optional: true

    validates :notification_type, presence: true, inclusion: { in: NOTIFICATION_TYPES }
    validates :level, inclusion: { in: LEVELS }, allow_blank: true
    validates :delivery_channel, presence: true, inclusion: { in: DELIVERY_CHANNELS }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :message, presence: true
    validates :generated_at, presence: true

    scope :recent_reactions, -> { where(reaction_received: true).where.not(reacted_at: nil).order(reacted_at: :desc) }

    scope :recently_sent_line, lambda { |since_time|
      where(delivery_channel: "line", status: "sent")
        .where("generated_at >= ?", since_time)
    }

    def self.recently_sent_duplicate?(customer:, learning_student:, notification_type:, since_time: 24.hours.ago)
      where(customer: customer,
            learning_student: learning_student,
            notification_type: notification_type)
        .recently_sent_line(since_time)
        .exists?
    end

    def self.auto_reminder_sent_today?(customer:, learning_student:, since_time: 24.hours.ago)
      where(customer: customer,
            learning_student: learning_student,
            notification_type: AUTO_REMINDER_TYPES)
        .recently_sent_line(since_time)
        .exists?
    end
  end
end
