class Learning::StudentPortalsController < ApplicationController
  helper LearningHelper

  skip_before_action :authenticate_customer!

  def show
    @student = LearningStudent
      .includes(:learning_school_group, :learning_student_parts,
                { learning_student_trainings: :learning_training_master }, :learning_progress_logs,
                :learning_assignments)
      .find_by!(public_access_token: params[:token])

    LearningPortalAccess.record_access!(@student)

    trainings = @student.learning_student_trainings.ordered.to_a
    recent_logs = @student.learning_progress_logs.recent_first.limit(10)
    achievement_count = trainings.count(&:star?)

    @summary = {
      total_count: trainings.count,
      achievement_count: achievement_count,
      progress_rate: trainings.count.zero? ? 0 : ((achievement_count.to_f / trainings.count) * 100).round,
      weekly_goal: trainings.map(&:weekly_goal).find(&:present?),
      teacher_comment: trainings.map(&:teacher_comment).find(&:present?)
    }
    @current_trainings = trainings.first(8)
    @weekly_training_assignments = @student.learning_assignments
      .includes(learning_student_training: :learning_training_master)
      .where(status: LearningAssignment::ACTION_REQUIRED_STATUSES)
      .where.not(learning_student_training_id: nil)
      .recent_first
      .limit(8)
    @current_assignments = @student.learning_assignments
      .where(status: LearningAssignment::ACTION_REQUIRED_STATUSES)
      .recent_first
      .limit(5)
    @has_overdue_assignments = @current_assignments.any?(&:overdue?)
    @recent_logs = recent_logs
    @current_streak  = LearningPortalAccess.current_streak(@student)
    @effort_points   = @student.total_effort_points
    @show_tutorial   = !@student.tutorial_completed?
    @ranking         = @student.rank_within_group
    @today_task      = Learning::FirstDayExperience.today_task(@student)
    @reminder        = Learning::ReminderService.for_student(
      @student,
      last_practiced_on: @student.learning_progress_logs.maximum(:practiced_on)
    )
    start_guide_service = Learning::StartGuideService.new(@student)
    @start_guide = start_guide_service.guide
    @student_feedback = start_guide_service.feedback
    @student_badges = start_guide_service.badges
    @yesterday_training_title = start_guide_service.yesterday_summary
    @idle_days = start_guide_service.idle_days
    @show_comeback_message = start_guide_service.comeback?
    @weekly_active_student_count = @student.customer.learning_progress_logs
      .where(practiced_on: Date.current.all_week)
      .distinct
      .count(:learning_student_id)
    @part_recommendations = Learning::FirstDayExperience.recommendations_for(@student)
    @line_connected = @student.line_connected?
  end

  def complete_tutorial
    student = LearningStudent.find_by!(public_access_token: params[:token])
    student.update!(tutorial_completed: true)
    head :ok
  end
end
