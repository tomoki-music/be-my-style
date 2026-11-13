class LearningMailer < ApplicationMailer
  def student_portal_mail
    @teacher = params[:teacher]
    # 生徒へのメールは先生のアカウントから送るもの。先生が退会していれば送らない。
    require_notifiable_customer(@teacher)
    @student = params[:student]
    @portal_url = @student.portal_url
    trainings = @student.learning_student_trainings.ordered.to_a
    achievement_count = trainings.count(&:star?)

    @summary = {
      total_count: trainings.count,
      achievement_count: achievement_count,
      progress_rate: trainings.count.zero? ? 0 : ((achievement_count.to_f / trainings.count) * 100).round,
      weekly_goal: trainings.map(&:weekly_goal).find(&:present?),
      teacher_comment: trainings.map(&:teacher_comment).find(&:present?)
    }
    @upcoming_trainings = trainings.reject(&:star?).first(3)

    mail to: @student.email, subject: "#{@student.name}さんの今週のトレーニングまとめ"
  end
end
