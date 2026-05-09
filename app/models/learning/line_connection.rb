module Learning
  class LineConnection < ApplicationRecord
    self.table_name = "learning_line_connections"

    STATUSES = %w[pending connected disabled].freeze

    belongs_to :customer
    belongs_to :learning_student, class_name: "LearningStudent", optional: true

    validates :line_user_id, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
  end
end
