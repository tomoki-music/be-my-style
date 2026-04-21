class LearningBandMembership < ApplicationRecord
  belongs_to :learning_band
  belongs_to :learning_student

  validates :learning_student_id, uniqueness: { scope: :learning_band_id }
end
