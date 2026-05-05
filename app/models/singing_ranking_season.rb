class SingingRankingSeason < ApplicationRecord
  has_many :singing_season_ranking_entries, dependent: :destroy

  STATUSES = %w[draft active closed].freeze
  SEASON_TYPES = %w[monthly].freeze

  validates :name, presence: true
  validates :starts_on, presence: true
  validates :ends_on, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :season_type, presence: true, inclusion: { in: SEASON_TYPES }
  validate :ends_on_must_be_on_or_after_starts_on

  scope :active, -> { where(status: "active") }
  scope :closed, -> { where(status: "closed") }
  scope :current, -> { active.where("starts_on <= ? AND ends_on >= ?", Date.current, Date.current) }
  scope :recent, -> { order(starts_on: :desc) }

  private

  def ends_on_must_be_on_or_after_starts_on
    return if starts_on.blank? || ends_on.blank?

    errors.add(:ends_on, "は開始日以降の日付を指定してください") if ends_on < starts_on
  end
end
