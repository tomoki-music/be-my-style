class Learning::TeacherDashboardsController < Learning::BaseController
  def show
    @school_groups = current_customer.learning_school_groups.ordered
    @selected_school_group = current_customer.learning_school_groups.find_by(id: params[:group_id])
    @students = current_customer.learning_students
                                .includes(:learning_school_group,
                                          :learning_student_trainings,
                                          :learning_progress_logs)
                                .active
    @students = @students.where(learning_school_group_id: @selected_school_group.id) if @selected_school_group.present?
    @students = @students
                                .ordered
    @monthly_report = LearningMonthlyReport.for_month(current_customer)
    @notification_setting = Learning::NotificationSetting.effective_for(current_customer)
    @notification_candidates_count = Learning::NotificationDispatcher.new(current_customer).preview.count
    @notification_logs_count = current_customer.learning_notification_logs.count
    @onboarding_status = Learning::OnboardingStatus.new(current_customer, routes: self)
    @teacher_next_action = Learning::FirstDayExperience.teacher_action(current_customer, routes: self)
    @weekly_growth = build_weekly_growth
    @weekly_progress_points = Learning::FirstDayExperience.weekly_progress_points(current_customer)
    @weekly_review = Learning::WeeklyReviewService.new(current_customer, students: @students).build
    @recent_reaction_logs = current_customer.learning_notification_logs
      .includes(:learning_student)
      .where(learning_student_id: @students.map(&:id))
      .recent_reactions
      .limit(5)
    @last_practiced_on_by_student = current_customer.learning_progress_logs
      .where(learning_student_id: @students.map(&:id))
      .group(:learning_student_id)
      .maximum(:practiced_on)
    @achievement_rate_by_student = @students.to_h do |student|
      trainings = student.learning_student_trainings
      achieved_count = trainings.count { |training| training.status == "achieved" }
      rate = trainings.empty? ? 0 : ((achieved_count.to_f / trainings.size) * 100).round(1)
      [student.id, rate]
    end
  end

  def export_csv
    csv = Learning::CsvExporter.students_progress(current_customer)
    filename = "students_progress_#{Date.current.strftime('%Y%m%d')}.csv"
    send_data "﻿#{csv}", filename: filename,
                              type: "text/csv; charset=UTF-8",
                              disposition: "attachment"
  end

  private

  def build_weekly_growth
    current_week = Date.current.all_week
    last_week = 1.week.ago.to_date.all_week

    current_logs = current_customer.learning_progress_logs.where(practiced_on: current_week)
    last_week_log_count = current_customer.learning_progress_logs.where(practiced_on: last_week).count

    student_trainings = current_customer.learning_student_trainings
    total_trainings = student_trainings.count
    achieved_trainings = student_trainings.where(status: "achieved").count
    current_log_count = current_logs.count

    {
      active_student_count: current_logs.distinct.count(:learning_student_id),
      completed_training_count: student_trainings.where(status: "achieved", updated_at: current_week).count,
      average_achievement_rate: total_trainings.zero? ? nil : ((achieved_trainings.to_f / total_trainings) * 100).round,
      progress_log_count: current_log_count,
      log_count_delta: current_log_count - last_week_log_count
    }
  end
end
