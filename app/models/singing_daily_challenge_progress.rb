class SingingDailyChallengeProgress < ApplicationRecord
  belongs_to :customer
  belongs_to :singing_daily_challenge

  validates :customer_id, uniqueness: { scope: :singing_daily_challenge_id }

  def completed?
    completed_at.present?
  end
end
