class SingingBattle < ApplicationRecord
  enum status: {
    waiting:   0,
    completed: 1,
    expired:   2
  }

  belongs_to :challenger,            class_name: "Customer",        foreign_key: :challenger_id
  belongs_to :opponent,              class_name: "Customer",        foreign_key: :opponent_id,             optional: true
  belongs_to :challenger_diagnosis,  class_name: "SingingDiagnosis", foreign_key: :challenger_diagnosis_id
  belongs_to :opponent_diagnosis,    class_name: "SingingDiagnosis", foreign_key: :opponent_diagnosis_id,  optional: true

  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
  validates :challenger_id, presence: true
  validates :challenger_diagnosis_id, presence: true

  EXPIRES_IN = 7.days

  before_validation :assign_token, on: :create
  before_validation :assign_expires_at, on: :create

  scope :active, -> { where(status: :waiting).where("expires_at > ?", Time.current) }

  def expired?
    expires_at < Time.current
  end

  def open?
    waiting? && !expired?
  end

  def score_diff(attribute)
    challenger_score = challenger_diagnosis.public_send("#{attribute}_score")
    opponent_score   = opponent_diagnosis&.public_send("#{attribute}_score")
    return nil unless challenger_score && opponent_score

    challenger_score - opponent_score
  end

  def challenger_wins?(attribute = :overall)
    diff = score_diff(attribute)
    diff.present? && diff > 0
  end

  def opponent_wins?(attribute = :overall)
    diff = score_diff(attribute)
    diff.present? && diff < 0
  end

  def draw?(attribute = :overall)
    score_diff(attribute) == 0
  end

  private

  def assign_token
    self.token ||= SecureRandom.urlsafe_base64(16)
  end

  def assign_expires_at
    self.expires_at ||= EXPIRES_IN.from_now
  end
end
