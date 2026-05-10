class Learning::LineMessagesController < Learning::BaseController
  MESSAGE_MAX_LENGTH = 500

  before_action :set_student

  def create
    message = normalized_message

    if message.blank?
      return redirect_to learning_student_path(@student), alert: "LINEメッセージを入力してください。"
    end

    if message.length > MESSAGE_MAX_LENGTH
      return redirect_to learning_student_path(@student), alert: "LINEメッセージは#{MESSAGE_MAX_LENGTH}文字以内で入力してください。"
    end

    unless @student.line_connected?
      create_skipped_log(message)
      return redirect_to learning_student_path(@student), alert: "この生徒はLINE未連携のため送信できません。"
    end

    log = create_queued_log(message)
    result = Learning::LineNotificationAdapter.new.deliver(log)

    if result.success?
      redirect_to learning_student_path(@student), notice: "LINEメッセージを送信しました。"
    else
      redirect_to learning_student_path(@student), alert: "LINEメッセージ送信に失敗しました。通知ログを確認してください。"
    end
  end

  private

  def set_student
    @student = current_customer.learning_students.find(params[:student_id])
  end

  def normalized_message
    params.dig(:line_message, :message).to_s.strip
  end

  def create_queued_log(message)
    current_customer.learning_notification_logs.create!(
      learning_student: @student,
      notification_type: "teacher_message",
      level: "info",
      delivery_channel: "line",
      status: "queued",
      title: "先生からのメッセージ",
      message: message,
      recommended_action: "先生からのメッセージです。",
      generated_at: Time.current,
      metadata: { source: "Learning::LineMessagesController" }
    )
  end

  def create_skipped_log(message)
    log = create_queued_log(message)
    log.update!(
      status: "skipped",
      error_message: Learning::LineNotificationAdapter::NO_RECIPIENT_MESSAGE
    )
  end
end
