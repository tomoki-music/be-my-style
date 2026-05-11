class Learning::TeacherDashboardsController < Learning::BaseController
  def show
    @school_groups = current_customer.learning_school_groups.ordered
    @selected_school_group = current_customer.learning_school_groups.find_by(id: params[:group_id])
    @students = current_customer.learning_students
                                .includes(:learning_school_group,
                                          { learning_student_trainings: :learning_training_master },
                                          :learning_progress_logs,
                                          :learning_line_connections)
                                .active
    @students = @students.where(learning_school_group_id: @selected_school_group.id) if @selected_school_group.present?
    @students = @students
                                .ordered
    @monthly_report = LearningMonthlyReport.for_month(current_customer)
    @notification_setting = Learning::NotificationSetting.effective_for(current_customer)
    @notification_candidates_count = Learning::NotificationDispatcher.new(current_customer).preview.count
    @auto_reminder_summary = Learning::AutoReminderService.new(current_customer, dry_run: true).summary
    @notification_logs_count = current_customer.learning_notification_logs.count
    @onboarding_status = Learning::OnboardingStatus.new(current_customer, routes: self)
    @onboarding_checklist = Learning::OnboardingChecklist.new(current_customer, routes: self)
    @teacher_next_action = Learning::FirstDayExperience.teacher_action(current_customer, routes: self)
    @analytics_report = Learning::AnalyticsReport.new(current_customer, period: params[:period], students: @students)
    @line_message_templates = current_customer.learning_line_message_templates.active.ordered
    @weekly_growth = build_weekly_growth
    @weekly_assignment_status = build_weekly_assignment_status
    @weekly_progress_points = Learning::FirstDayExperience.weekly_progress_points(current_customer)
    @weekly_review = Learning::WeeklyReviewService.new(current_customer, students: @students).build
    @recent_reaction_logs = current_customer.learning_notification_logs
      .includes(:learning_student)
      .where(learning_student_id: @students.map(&:id))
      .recent_reactions
      .limit(5)
    @recent_completed_assignments = current_customer.learning_assignments
      .includes(:learning_student)
      .where(learning_student_id: @students.map(&:id))
      .completed_recent_first
      .limit(5)
    @pending_review_assignments = current_customer.learning_assignments
      .includes(:learning_student, :review_histories, learning_student_training: :learning_training_master)
      .where(learning_student_id: @students.map(&:id))
      .where(status: "pending_review")
      .select { |assignment| assignment.learning_student_training&.teacher_judged? }
      .first(6)
    @teacher_check_assignments = current_customer.learning_assignments
      .includes(:learning_student, learning_student_training: :learning_training_master)
      .where(learning_student_id: @students.map(&:id))
      .where(status: LearningAssignment::ACTION_REQUIRED_STATUSES)
      .select { |assignment| assignment.learning_student_training&.teacher_judged? }
      .first(6)
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

  def build_weekly_assignment_status
    current_week = Date.current.all_week
    weekly_assignments = current_customer.learning_assignments
      .where("created_at BETWEEN ? AND ? OR completed_at BETWEEN ? AND ? OR status IN (?)",
             current_week.begin, current_week.end,
             current_week.begin, current_week.end,
             LearningAssignment::INCOMPLETE_STATUSES)
    group_keys = weekly_assignments.where.not(assignment_group_key: nil).distinct.pluck(:assignment_group_key)
    sibling_assignments = group_keys.any? ? current_customer.learning_assignments.where(assignment_group_key: group_keys) : current_customer.learning_assignments.none
    assignments = current_customer.learning_assignments.where(id: weekly_assignments.select(:id)).or(sibling_assignments)
    assignments = current_customer.learning_assignments.active if assignments.none?
    total_count = assignments.count
    completed_count = assignments.where(status: "completed").count
    unsubmitted_count = assignments.where(status: LearningAssignment::ACTION_REQUIRED_STATUSES).count
    pending_review_count = assignments.where(status: "pending_review").count
    needs_revision_count = assignments.where(status: "needs_revision").count
    overdue_count = assignments.overdue.count

    {
      total_count: total_count,
      completed_count: completed_count,
      unsubmitted_count: unsubmitted_count,
      pending_review_count: pending_review_count,
      needs_revision_count: needs_revision_count,
      overdue_count: overdue_count,
      completion_rate: total_count.zero? ? 0 : ((completed_count.to_f / total_count) * 100).round
    }
  end
end
