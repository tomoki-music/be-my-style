class Learning::TeacherDashboardsController < Learning::BaseController
  def show
    @school_groups = current_customer.learning_school_groups.ordered
    @students = current_customer.learning_students
                                .includes(:learning_school_group,
                                          :learning_student_trainings,
                                          :learning_progress_logs)
                                .active
                                .ordered
    @monthly_report = LearningMonthlyReport.for_month(current_customer)
  end

  def export_csv
    csv = Learning::CsvExporter.students_progress(current_customer)
    filename = "students_progress_#{Date.current.strftime('%Y%m%d')}.csv"
    send_data "﻿#{csv}", filename: filename,
                              type: "text/csv; charset=UTF-8",
                              disposition: "attachment"
  end
end
