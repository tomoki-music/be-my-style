class ActivityReaction < ApplicationRecord
  REACTION_TYPES = %w[fire clap guitar mic].freeze
  REACTION_EMOJIS = {
    "fire" => "🔥",
    "clap" => "👏",
    "guitar" => "🎸",
    "mic" => "🎤"
  }.freeze

  belongs_to :customer
  belongs_to :activity

  after_create :create_notification

  validates :reaction_type, inclusion: { in: REACTION_TYPES }
  validates :customer_id, uniqueness: { scope: [:activity_id, :reaction_type] }

  def self.notification_action_for(reaction_type)
    return unless REACTION_TYPES.include?(reaction_type.to_s)

    "reaction_#{reaction_type}"
  end

  def self.reaction_type_from_notification_action(action)
    action.to_s.delete_prefix("reaction_")
  end

  def self.emoji_for(reaction_type)
    REACTION_EMOJIS[reaction_type.to_s] || "👏"
  end

  private

  def create_notification
    activity.customer.create_notification_activity_reaction(customer, activity.id, reaction_type)
  end
end
