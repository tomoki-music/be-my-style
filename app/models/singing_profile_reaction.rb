class SingingProfileReaction < ApplicationRecord
  REACTION_TYPES = %w[amazing cheer growth listen challenge].freeze
  REACTION_LABELS = {
    "amazing" => "すごい！",
    "cheer" => "応援してます！",
    "growth" => "成長ナイス！",
    "listen" => "また聴きたい！",
    "challenge" => "挑戦すてき！"
  }.freeze
  REACTION_EMOJIS = {
    "amazing" => "✨",
    "cheer" => "👏",
    "growth" => "🌱",
    "listen" => "🎧",
    "challenge" => "🎤"
  }.freeze

  belongs_to :customer
  belongs_to :target_customer, class_name: "Customer"

  validates :reaction_type, inclusion: { in: REACTION_TYPES }
  validates :customer_id, uniqueness: { scope: [:target_customer_id, :reaction_type] }
  validate :cannot_react_to_self

  def self.label_for(reaction_type)
    REACTION_LABELS[reaction_type.to_s]
  end

  def self.emoji_for(reaction_type)
    REACTION_EMOJIS[reaction_type.to_s] || "👏"
  end

  private

  def cannot_react_to_self
    return if customer_id.blank? || target_customer_id.blank?

    errors.add(:target_customer, "にはリアクションできません") if customer_id == target_customer_id
  end
end
