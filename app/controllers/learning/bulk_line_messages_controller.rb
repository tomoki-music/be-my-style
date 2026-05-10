class Learning::BulkLineMessagesController < Learning::BaseController
  MESSAGE_MAX_LENGTH = 500

  def create
    message = normalized_message
    student_ids = normalized_student_ids

    if message.blank?
      return redirect_to learning_students_path, alert: "LINE一括送信メッセージを入力してください。"
    end

    if message.length > MESSAGE_MAX_LENGTH
      return redirect_to learning_students_path, alert: "LINE一括送信メッセージは#{MESSAGE_MAX_LENGTH}文字以内で入力してください。"
    end

    if student_ids.blank?
      return redirect_to learning_students_path, alert: "送信する生徒を選択してください。"
    end

    result = deliver_to_students(student_ids, message)
    redirect_to learning_students_path, notice: result.flash_message
  end

  private

  BulkResult = Struct.new(:sent_count, :skipped_count, :failed_count, keyword_init: true) do
    def flash_message
      "LINE一括送信が完了しました。送信成功：#{sent_count}件 / 未連携スキップ：#{skipped_count}件 / 失敗：#{failed_count}件"
    end
  end

  def normalized_message
    (params.dig(:bulk_line_message, :message).presence || params[:message]).to_s.strip
  end

  def normalized_student_ids
    Array(params[:student_ids]).map(&:presence).compact.uniq
  end

  def deliver_to_students(student_ids, message)
    counts = { sent_count: 0, skipped_count: 0, failed_count: 0 }
    students = current_customer.learning_students
      .includes(:learning_line_connections)
      .where(id: student_ids)
      .index_by { |student| student.id.to_s }
    adapter = Learning::LineNotificationAdapter.new

    student_ids.each do |student_id|
      student = students[student_id.to_s]
      next unless student

      if student.line_connected?
        deliver_to_connected_student(adapter, student, message, counts)
      else
        create_skipped_log(student, message)
        counts[:skipped_count] += 1
      end
    end

    BulkResult.new(**counts)
  end

  def deliver_to_connected_student(adapter, student, message, counts)
    log = create_queued_log(student, message)
    result = adapter.deliver(log)

    if result.success?
      counts[:sent_count] += 1
    elsif log.reload.status == "skipped"
      counts[:skipped_count] += 1
    else
      log.update!(status: "failed", error_message: result.message) unless log.status == "failed"
      counts[:failed_count] += 1
    end
  rescue StandardError => e
    log&.update!(status: "failed", error_message: "#{Learning::LineNotificationAdapter::HTTP_ERROR_MESSAGE}: #{e.class.name}")
    counts[:failed_count] += 1
  end

  def create_queued_log(student, message)
    current_customer.learning_notification_logs.create!(
      learning_student: student,
      notification_type: "teacher_bulk_message",
      level: "info",
      delivery_channel: "line",
      status: "queued",
      title: "先生からの一括メッセージ",
      message: message,
      recommended_action: "先生からの一括メッセージです。",
      generated_at: Time.current,
      metadata: { source: "Learning::BulkLineMessagesController" }
    )
  end

  def create_skipped_log(student, message)
    log = create_queued_log(student, message)
    log.update!(
      status: "skipped",
      error_message: Learning::LineNotificationAdapter::NO_RECIPIENT_MESSAGE
    )
  end
end
