module Learning
  class WeeklyReminderJob < ApplicationJob
    queue_as :default

    def perform
      Customer.joins(:learning_students)
              .merge(LearningStudent.active)
              .distinct.find_each do |teacher|
        Learning::ReminderService.for_customer(teacher).each do |reminder|
          Rails.logger.info(
            "[Learning::WeeklyReminderJob] reminder student_id=#{reminder.student.id} " \
            "stage=#{reminder.stage} days_idle=#{reminder.days_idle} tone=#{reminder.tone} " \
            "message=#{reminder.message}"
          )
        end

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
