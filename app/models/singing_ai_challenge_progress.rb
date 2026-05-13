class SingingAiChallengeProgress < ApplicationRecord
  TARGET_KEYS = %w[habit pitch rhythm expression].freeze

  belongs_to :customer

  validates :target_key, presence: true, inclusion: { in: TARGET_KEYS }
  validates :challenge_month, presence: true
  validates :tried, :completed, :next_diagnosis_planned, inclusion: { in: [true, false] }
  validates :target_key, uniqueness: { scope: [:customer_id, :challenge_month] }

  before_save :sync_completed_at

  private

  def sync_completed_at
    if completed?
      self.completed_at ||= Time.current
    else
      self.completed_at = nil
    end
  end
end
