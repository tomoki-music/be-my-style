module Learning
  class WeeklyReminderJob < ApplicationJob
    queue_as :default

    def perform
      Customer.joins(:learning_students)
              .merge(LearningStudent.active)
              .distinct.find_each do |teacher|
        teacher.learning_students.active.each do |student|
          next unless student.email.present?

          LearningMailer.student_portal_mail(teacher, student).deliver_later
        rescue => e
          Rails.logger.error "[Learning::WeeklyReminderJob] student_id=#{student.id} error=#{e.message}"
        end
      end
    end
  end
end
