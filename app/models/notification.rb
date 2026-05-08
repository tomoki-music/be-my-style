class Notification < ApplicationRecord
  LEARNING_ACTION_TYPES = {
    reminder: "learning_reminder",
    teacher_action: "learning_teacher_action",
    weekly_summary: "learning_weekly_summary"
  }.freeze

  default_scope -> { order(created_at: :desc) }
  belongs_to :event, optional: true
  belongs_to :comment, optional: true
  belongs_to :activity, optional: true
  belongs_to :community, optional: true
  belongs_to :post, optional: true
  belongs_to :project, optional: true

  belongs_to :visitor, class_name: 'Customer', foreign_key: 'visitor_id', optional: true
  belongs_to :visited, class_name: 'Customer', foreign_key: 'visited_id', optional: true
end
