require "csv"

module Learning
  class CsvExporter
    def self.students_progress(customer)
      students = customer.learning_students
                         .includes(:learning_school_group,
                                   :learning_student_trainings,
                                   :learning_effort_points)
                         .active
                         .ordered

      CSV.generate(headers: true, encoding: "UTF-8") do |csv|
        csv << ["名前", "ニックネーム", "パート", "学年", "グループ",
                "課題数", "達成数", "達成率(%)", "努力ポイント", "最終練習日"]

        students.each do |student|
          trainings = student.learning_student_trainings
          achieved  = trainings.where(status: "achieved").count
          last_log  = student.learning_progress_logs.maximum(:practiced_on)

          csv << [
            student.name,
            student.nickname,
            student.main_part,
            student.grade,
            student.learning_school_group&.name,
            trainings.count,
            achieved,
            student.achievement_rate,
            student.total_effort_points,
            last_log
          ]
        end
      end
    end
  end
end
