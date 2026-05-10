module Learning
  class NotificationLog < ApplicationRecord
    self.table_name = "learning_notification_logs"

    NOTIFICATION_TYPES = %w[
      reminder
      teacher_action
      teacher_message
      weekly_summary
      student_reactivation
    ].freeze

    LEVELS = %w[light normal strong info].freeze
    DELIVERY_CHANNELS = %w[manual email line].freeze
    STATUSES = %w[previewed queued sent failed skipped].freeze

    belongs_to :customer
    belongs_to :learning_student, class_name: "LearningStudent", optional: true

    validates :notification_type, presence: true, inclusion: { in: NOTIFICATION_TYPES }
    validates :level, inclusion: { in: LEVELS }, allow_blank: true
    validates :delivery_channel, presence: true, inclusion: { in: DELIVERY_CHANNELS }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :message, presence: true
    validates :generated_at, presence: true

    scope :recent_reactions, -> { where(reaction_received: true).where.not(reacted_at: nil).order(reacted_at: :desc) }
  end
end
