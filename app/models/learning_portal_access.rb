class LearningPortalAccess < ApplicationRecord
  belongs_to :learning_student

  validates :accessed_on, presence: true,
                           uniqueness: { scope: :learning_student_id }

  def self.record_access!(student)
    today = Date.current
    return if exists?(learning_student: student, accessed_on: today)

    yesterday_record = find_by(learning_student: student, accessed_on: today - 1)
    streak = yesterday_record ? yesterday_record.streak_count + 1 : 1

    create!(learning_student: student, accessed_on: today, streak_count: streak)
    award_streak_bonus!(student, streak)
  end

  def self.current_streak(student)
    find_by(learning_student: student, accessed_on: Date.current)&.streak_count || 0
  end

  class << self
    private

    def award_streak_bonus!(student, streak)
      # 7日の倍数でボーナス付与
      return unless streak > 1 && (streak % 7).zero?

      pts = LearningEffortPoint::POINT_TYPES["streak_bonus"][:points]
      LearningEffortPoint.create!(
        customer_id: student.customer_id,
        learning_student: student,
        point_type: "streak_bonus",
        points: pts,
        description: "#{streak}日連続アクセスボーナス",
        earned_on: Date.current
      )
      student.increment!(:total_effort_points, pts)
    end
  end
end
