class Learning::StudentPortalsController < ApplicationController
  skip_before_action :authenticate_customer!

  def show
    @student = LearningStudent
      .includes(:learning_school_group, :learning_student_parts, :learning_student_trainings, :learning_progress_logs)
      .find_by!(public_access_token: params[:token])

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
    @recent_logs = recent_logs
  end
end
