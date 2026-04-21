class LearningBand < ApplicationRecord
  belongs_to :customer
  has_many :learning_band_trainings, dependent: :destroy
  has_many :learning_band_memberships, dependent: :destroy
  has_many :learning_students, through: :learning_band_memberships

  validates :name, presence: true, length: { maximum: 60 }
  validates :name, uniqueness: { scope: :customer_id }
  validates :memo, length: { maximum: 500 }

  scope :ordered, -> { order(:name) }

  def sync_students!(student_ids)
    normalized_ids = Array(student_ids).map(&:presence).compact.map(&:to_i).uniq

    transaction do
      learning_band_memberships.where.not(learning_student_id: normalized_ids).destroy_all

      normalized_ids.each do |student_id|
        learning_band_memberships.find_or_create_by!(learning_student_id: student_id)
      end
    end
  end
end
