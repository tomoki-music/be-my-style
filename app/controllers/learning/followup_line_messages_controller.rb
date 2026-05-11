class Learning::FollowupLineMessagesController < Learning::BaseController
  MESSAGE_MAX_LENGTH = 500
  DEFAULT_MESSAGE = "最近の練習状況が少し止まっているみたいです！5分だけでもOKなので、まずは一歩だけやってみよう🔥終わったら「やった！」と返信してね！".freeze

  def create
    message = normalized_message
    student_ids = normalized_student_ids

    if message.blank?
      return redirect_to teacher_dashboard_path, alert: "フォローLINEメッセージを入力してください。"
    end

    if message.length > MESSAGE_MAX_LENGTH
      return redirect_to teacher_dashboard_path, alert: "フォローLINEメッセージは#{MESSAGE_MAX_LENGTH}文字以内で入力してください。"
    end

    if student_ids.blank?
      return redirect_to teacher_dashboard_path, alert: "送信する要フォロー生徒を選択してください。"
    end

    result = deliver_to_students(student_ids, message)
    redirect_to teacher_dashboard_path, notice: result.flash_message
  end

  private

  FollowupResult = Struct.new(:sent_count, :skipped_count, :duplicate_count, :failed_count, keyword_init: true) do
    def flash_message
      "フォローLINE送信完了。成功：#{sent_count}件 / 未連携：#{skipped_count}件 / 重複スキップ：#{duplicate_count}件 / 失敗：#{failed_count}件"
    end
  end

  def teacher_dashboard_path
    learning_teacher_dashboard_path(period: params[:period], group_id: params[:group_id])
  end

  def normalized_message
    (params.dig(:followup_line_message, :message).presence || params[:message]).to_s.strip
  end

  def normalized_student_ids
    Array(params[:student_ids]).map(&:presence).compact.uniq
  end

  def deliver_to_students(student_ids, message)
    counts = { sent_count: 0, skipped_count: 0, duplicate_count: 0, failed_count: 0 }
    students = eligible_students_by_id(student_ids)
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

    FollowupResult.new(**counts)
  end

  def eligible_students_by_id(student_ids)
    students = current_customer.learning_students
      .includes(:learning_line_connections, :learning_assignments)
      .active
      .where(id: student_ids)
    report = Learning::AnalyticsReport.new(current_customer, period: params[:period], students: students)

    report.at_risk_students
      .map(&:student)
      .index_by { |student| student.id.to_s }
  end

  def deliver_to_connected_student(adapter, student, message, counts)
    if recently_sent_duplicate?(student)
      create_duplicate_log(student, message)
      counts[:duplicate_count] += 1
      return
    end

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
      notification_type: "followup_message",
      level: "info",
      delivery_channel: "line",
      status: "queued",
      title: "先生からの応援メッセージ",
      message: message,
      recommended_action: "5分だけ練習して、終わったらLINEで返信する",
      generated_at: Time.current,
      metadata: { source: "Learning::FollowupLineMessagesController" }
    )
  end

  def create_skipped_log(student, message)
    log = create_queued_log(student, message)
    log.update!(
      status: "skipped",
      error_message: Learning::LineNotificationAdapter::NO_RECIPIENT_MESSAGE
    )
  end

  def create_duplicate_log(student, message)
    log = create_queued_log(student, message)
    log.update!(
      status: "skipped",
      error_message: Learning::NotificationLog::DUPLICATE_RECENTLY_SENT_MESSAGE
    )
  end

  def recently_sent_duplicate?(student)
    Learning::NotificationLog.recently_sent_duplicate?(
      customer: current_customer,
      learning_student: student,
      notification_type: "followup_message"
    )
  end
end
