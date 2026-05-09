class Learning::LineTestMessagesController < Learning::BaseController
  before_action :set_student

  def create
    log = current_customer.learning_notification_logs.create!(
      learning_student: @student,
      notification_type: "teacher_action",
      level: "info",
      delivery_channel: "line",
      status: "queued",
      title: "LINEテスト送信",
      message: "#{@student.display_name}さん、BeMyStyle LearningからのLINEテスト通知です。",
      recommended_action: "この通知が届いていれば、LINE連携は完了しています。",
      generated_at: Time.current,
      metadata: { source: "Learning::LineTestMessagesController" }
    )

    result = Learning::LineNotificationAdapter.new.deliver(log)
    if result.success?
      redirect_to learning_student_path(@student), notice: "LINEテスト送信に成功しました。"
    else
      redirect_to learning_student_path(@student), alert: "LINEテスト送信に失敗しました: #{result.message}"
    end
  end

  private

  def set_student
    @student = current_customer.learning_students.find(params[:student_id])
  end
end
