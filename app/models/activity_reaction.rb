class ActivityReaction < ApplicationRecord
  REACTION_TYPES = %w[fire clap guitar mic].freeze

  belongs_to :customer
  belongs_to :activity

  validates :reaction_type, inclusion: { in: REACTION_TYPES }
  validates :customer_id, uniqueness: { scope: [:activity_id, :reaction_type] }
end
