class LearningAssignmentReviewHistory < ApplicationRecord
  ACTIONS = %w[submitted approved revision_requested].freeze

  ACTION_LABELS = {
    "submitted" => "生徒が提出",
    "approved" => "先生が承認",
    "revision_requested" => "先生が差し戻し"
  }.freeze

  belongs_to :learning_assignment
  belongs_to :reviewer, class_name: "Customer", optional: true

  validates :action, presence: true, inclusion: { in: ACTIONS }

  scope :chronological, -> { order(created_at: :asc) }
  scope :reverse_chronological, -> { order(created_at: :desc) }

  def action_label
    ACTION_LABELS.fetch(action, action)
  end

  def submitted?
    action == "submitted"
  end

  def approved?
    action == "approved"
  end

  def revision_requested?
    action == "revision_requested"
  end
end
