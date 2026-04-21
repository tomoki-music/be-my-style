class LearningStudentPart < ApplicationRecord
  belongs_to :learning_student

  validates :part, presence: true, inclusion: { in: LearningCatalog::PARTS.keys }
  validates :part, uniqueness: { scope: :learning_student_id }
end
