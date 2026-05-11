class Learning::AssignmentsController < Learning::BaseController
  TITLE_MAX_LENGTH = 100
  DESCRIPTION_MAX_LENGTH = 1000
  DEFAULT_REMINDER_MESSAGE = "今週のトレーニング、まだ取り組めていません！5分だけでも取り組んでみよう。終わったら「やった！」と返信してね。".freeze
  REVISION_REQUEST_DEFAULT_MESSAGE = "もう一度チャレンジしてみましょう。できたらLINEで「やった」と返信してください！".freeze

  AssignmentSummary = Struct.new(:representative, :assignments, keyword_init: true) do
    def title
      representative.title
    end

    def description
      representative.description
    end

    def due_on
      representative.due_on
    end

    def created_at
      representative.created_at
    end

    def total_count
      assignments.size
    end

    def completed_count
      assignments.count { |assignment| assignment.status == "completed" }
    end

    def pending_count
      assignments.count { |assignment| assignment.status == "pending" }
    end

    def in_progress_count
      assignments.count { |assignment| assignment.status == "in_progress" }
    end

    def pending_review_count
      assignments.count { |assignment| assignment.status == "pending_review" }
    end

    def needs_revision_count
      assignments.count { |assignment| assignment.status == "needs_revision" }
    end

    def unsubmitted_count
      pending_count + in_progress_count + needs_revision_count
    end

    def overdue_count
      assignments.count(&:overdue?)
    end

    def completion_rate
      return 0 if total_count.zero?

      ((completed_count.to_f / total_count) * 100).round
    end
  end

  StudentProgress = Struct.new(:assignment, :student, :last_reaction_log, keyword_init: true) do
    def status
      assignment.status
    end

    def status_label
      assignment.status_label
    end

    def line_connected?
      student.line_connected?
    end

    def overdue?
      assignment.overdue?
    end

    def inactive?
      last_reaction_log.blank? || last_reaction_log.reacted_at < 3.days.ago
    end
  end

  def index
    @assignment_summaries = grouped_assignment_summaries(current_customer.learning_assignments.includes(:learning_student).recent_first)
  end

  def show
    @assignment = current_customer.learning_assignments
      .includes(:learning_student, learning_student_training: :learning_training_master)
      .find(params[:id])
    @assignments = assignment_group_for(@assignment)
    @assignment_summary = AssignmentSummary.new(representative: @assignment, assignments: @assignments)
    @student_progresses = filtered_student_progresses(@assignments)
    @reminder_message = DEFAULT_REMINDER_MESSAGE
  end

  def create
    title = normalized_title
    description = normalized_description
    student_ids = normalized_student_ids

    if title.blank?
      return redirect_to learning_students_path, alert: "課題タイトルを入力してください。"
    end

    if title.length > TITLE_MAX_LENGTH
      return redirect_to learning_students_path, alert: "課題タイトルは#{TITLE_MAX_LENGTH}文字以内で入力してください。"
    end

    if description.length > DESCRIPTION_MAX_LENGTH
      return redirect_to learning_students_path, alert: "課題内容は#{DESCRIPTION_MAX_LENGTH}文字以内で入力してください。"
    end

    if student_ids.blank?
      return redirect_to learning_students_path, alert: "課題を配布する生徒を選択してください。"
    end

    result = distribute_to_students(student_ids, title, description)
    redirect_to learning_students_path, notice: result.flash_message
  end

  def bulk_reminder
    assignment = current_customer.learning_assignments.find(params[:id])
    assignments = assignment_group_for(assignment)
    message = normalized_reminder_message

    if message.blank?
      return redirect_to learning_assignment_path(assignment), alert: "未提出者へのLINEメッセージを入力してください。"
    end

    if message.length > Learning::BulkLineMessagesController::MESSAGE_MAX_LENGTH
      return redirect_to learning_assignment_path(assignment), alert: "LINEメッセージは#{Learning::BulkLineMessagesController::MESSAGE_MAX_LENGTH}文字以内で入力してください。"
    end

    result = deliver_reminder(assignments, message)
    redirect_to learning_assignment_path(assignment), notice: result.flash_message
  end

  def approve_review
    assignment = current_customer.learning_assignments
      .includes(:learning_student, learning_student_training: :learning_training_master)
      .find(params[:id])

    unless assignment.teacher_review_required? && assignment.pending_review?
      return redirect_back fallback_location: learning_teacher_dashboard_path, alert: "承認待ちの課題ではありません。"
    end

    assignment.approve_review!(reviewer: current_customer, comment: params[:review_comment])
    redirect_back fallback_location: learning_teacher_dashboard_path, notice: "確認しました。"
  end

  def request_revision
    assignment = current_customer.learning_assignments
      .includes(:learning_student, learning_student_training: :learning_training_master)
      .find(params[:id])

    unless assignment.teacher_review_required? && assignment.pending_review?
      return redirect_back fallback_location: learning_teacher_dashboard_path, alert: "先生確認待ちの課題ではありません。"
    end

    assignment.request_revision!(reviewer: current_customer, comment: params[:review_comment])
    deliver_revision_request(assignment)
    redirect_back fallback_location: learning_teacher_dashboard_path, notice: "差し戻しました。"
  end

  private

  DistributionResult = Struct.new(:created_count, :sent_count, :skipped_count, :failed_count, keyword_init: true) do
    def flash_message
      "課題配布が完了しました。配布：#{created_count}件 / LINE通知成功：#{sent_count}件 / 未連携スキップ：#{skipped_count}件 / 失敗：#{failed_count}件"
    end
  end

  BulkReminderResult = Struct.new(:sent_count, :skipped_count, :failed_count, keyword_init: true) do
    def flash_message
      "未提出者へのLINE送信が完了しました。送信成功：#{sent_count}件 / 未連携スキップ：#{skipped_count}件 / 失敗：#{failed_count}件"
    end
  end

  def normalized_title
    params.dig(:learning_assignment, :title).to_s.strip
  end

  def normalized_description
    params.dig(:learning_assignment, :description).to_s.strip
  end

  def normalized_due_on
    params.dig(:learning_assignment, :due_on).presence
  end

  def normalized_student_ids
    Array(params[:student_ids]).map(&:presence).compact.uniq
  end

  def normalized_reminder_message
    (params.dig(:assignment_reminder, :message).presence || DEFAULT_REMINDER_MESSAGE).to_s.strip
  end

  def distribute_to_students(student_ids, title, description)
    counts = { created_count: 0, sent_count: 0, skipped_count: 0, failed_count: 0 }
    group_key = SecureRandom.uuid
    students = current_customer.learning_students
      .includes(:learning_line_connections)
      .where(id: student_ids)
      .index_by { |student| student.id.to_s }
    adapter = Learning::LineNotificationAdapter.new

    student_ids.each do |student_id|
      student = students[student_id.to_s]
      next unless student

      distribute_to_student(student, title, description, group_key, adapter, counts)
    end

    DistributionResult.new(**counts)
  end

  def distribute_to_student(student, title, description, group_key, adapter, counts)
    assignment = current_customer.learning_assignments.create!(
      learning_student: student,
      title: title,
      description: description,
      due_on: normalized_due_on,
      status: "pending",
      assignment_group_key: group_key
    )
    counts[:created_count] += 1

    log = create_queued_log(student, assignment)
    if student.line_connected?
      deliver_assignment_log(adapter, log, counts)
    else
      log.update!(status: "skipped", error_message: Learning::LineNotificationAdapter::NO_RECIPIENT_MESSAGE)
      counts[:skipped_count] += 1
    end
  rescue ActiveRecord::RecordInvalid
    counts[:failed_count] += 1
  end

  def deliver_assignment_log(adapter, log, counts)
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

  def create_queued_log(student, assignment)
    current_customer.learning_notification_logs.create!(
      learning_student: student,
      notification_type: "assignment_created",
      level: "info",
      delivery_channel: "line",
      status: "queued",
      title: assignment.title,
      message: assignment.description.presence || assignment.title,
      recommended_action: assignment.due_on ? "期限: #{assignment.due_on.strftime('%-m/%-d')}" : nil,
      generated_at: Time.current,
      metadata: {
        source: "Learning::AssignmentsController",
        learning_assignment_id: assignment.id,
        learning_student_training_id: assignment.learning_student_training_id
      }
    )
  end

  def grouped_assignment_summaries(assignments)
    assignments
      .group_by(&:grouping_key)
      .values
      .map { |group_assignments| AssignmentSummary.new(representative: group_assignments.max_by(&:created_at), assignments: group_assignments) }
      .sort_by(&:created_at)
      .reverse
  end

  def assignment_group_for(assignment)
    scope = current_customer.learning_assignments.includes(:learning_student, learning_student_training: :learning_training_master)
    if assignment.assignment_group_key.present?
      scope.where(assignment_group_key: assignment.assignment_group_key).order(:created_at, :id).to_a
    else
      [assignment]
    end
  end

  def filtered_student_progresses(assignments)
    logs_by_student_id = latest_reaction_logs_for(assignments)
    progresses = assignments.map do |assignment|
      StudentProgress.new(
        assignment: assignment,
        student: assignment.learning_student,
        last_reaction_log: logs_by_student_id[assignment.learning_student_id]
      )
    end

    progresses = progresses.select { |progress| LearningAssignment::ACTION_REQUIRED_STATUSES.include?(progress.status) } if params[:status] == "unsubmitted"
    progresses = progresses.reject(&:line_connected?) if params[:line] == "unconnected"
    progresses = progresses.select(&:inactive?) if params[:inactive] == "1"
    progresses
  end

  def latest_reaction_logs_for(assignments)
    student_ids = assignments.map(&:learning_student_id)
    current_customer.learning_notification_logs
      .where(learning_student_id: student_ids, reaction_received: true)
      .where.not(reacted_at: nil)
      .order(reacted_at: :desc, id: :desc)
      .group_by(&:learning_student_id)
      .transform_values(&:first)
  end

  def deliver_reminder(assignments, message)
    counts = { sent_count: 0, skipped_count: 0, failed_count: 0 }
    adapter = Learning::LineNotificationAdapter.new

    assignments.select(&:action_required?).each do |assignment|
      student = assignment.learning_student
      if student.line_connected?
        deliver_reminder_to_connected_student(adapter, assignment, message, counts)
      else
        create_skipped_reminder_log(assignment, message)
        counts[:skipped_count] += 1
      end
    end

    BulkReminderResult.new(**counts)
  end

  def deliver_reminder_to_connected_student(adapter, assignment, message, counts)
    log = create_reminder_log(assignment, message)
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

  def create_reminder_log(assignment, message)
    current_customer.learning_notification_logs.create!(
      learning_student: assignment.learning_student,
      notification_type: "teacher_bulk_message",
      level: "info",
      delivery_channel: "line",
      status: "queued",
      title: "今週のトレーニングフォロー",
      message: "#{assignment.title}\n#{message}",
      recommended_action: "今週のトレーニング未実施者フォローです。",
      generated_at: Time.current,
      metadata: {
        source: "Learning::AssignmentsController#bulk_reminder",
        learning_assignment_id: assignment.id,
        learning_student_training_id: assignment.learning_student_training_id,
        assignment_group_key: assignment.grouping_key
      }
    )
  end

  def create_skipped_reminder_log(assignment, message)
    log = create_reminder_log(assignment, message)
    log.update!(
      status: "skipped",
      error_message: Learning::LineNotificationAdapter::NO_RECIPIENT_MESSAGE
    )
  end

  def deliver_revision_request(assignment)
    log = create_revision_request_log(assignment)
    if assignment.learning_student.line_connected?
      result = Learning::LineNotificationAdapter.new.deliver(log)
      log.update!(status: "failed", error_message: result.message) unless result.success? || log.reload.status == "skipped"
    else
      log.update!(status: "skipped", error_message: Learning::LineNotificationAdapter::NO_RECIPIENT_MESSAGE)
    end
  rescue StandardError => e
    log&.update!(status: "failed", error_message: "#{Learning::LineNotificationAdapter::HTTP_ERROR_MESSAGE}: #{e.class.name}")
  end

  def create_revision_request_log(assignment)
    comment = assignment.review_comment.presence || REVISION_REQUEST_DEFAULT_MESSAGE
    current_customer.learning_notification_logs.create!(
      learning_student: assignment.learning_student,
      notification_type: "teacher_revision_request",
      level: "info",
      delivery_channel: "line",
      status: "queued",
      title: "もう一度チャレンジ",
      message: comment,
      recommended_action: "先生からのコメントを確認して、もう一度チャレンジしてみましょう！",
      generated_at: Time.current,
      metadata: {
        source: "Learning::AssignmentsController#request_revision",
        learning_assignment_id: assignment.id,
        learning_student_training_id: assignment.learning_student_training_id,
        assignment_group_key: assignment.grouping_key
      }
    )
  end
end
