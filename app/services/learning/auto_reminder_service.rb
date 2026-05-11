# frozen_string_literal: true

require "set"

module Learning
  class AutoReminderService
    Candidate = Struct.new(:student, :notification_type, :reason, :message, :title,
                           :recommended_action, :assignment, :level, :generated_at,
                           keyword_init: true)
    Result = Struct.new(:candidate, :log, :status, :message, keyword_init: true)
    Summary = Struct.new(:inactive_count, :due_tomorrow_count, :overdue_count, keyword_init: true) do
      def total_count
        inactive_count + due_tomorrow_count + overdue_count
      end
    end

    INACTIVE_TYPE = "auto_inactive_reminder"
    DUE_TYPE = "auto_assignment_due_reminder"
    OVERDUE_TYPE = "auto_assignment_overdue_reminder"
    AUTO_TYPES = [INACTIVE_TYPE, DUE_TYPE, OVERDUE_TYPE].freeze

    INACTIVE_THRESHOLD = 3.days
    DEDUPE_WINDOW = 24.hours

    FALLBACK_MESSAGES = {
      INACTIVE_TYPE => "少し間が空いています。今日は5分だけでも、できるところから再開してみよう。",
      DUE_TYPE => "明日が期限の課題があります。短い時間でよいので、今日のうちに確認しておこう。",
      OVERDUE_TYPE => "期限を過ぎた課題があります。まずは1つだけ開いて、できるところから進めよう。"
    }.freeze

    def initialize(customer, dry_run: false, line_adapter: LineNotificationAdapter.new, logger: Rails.logger)
      @customer = customer
      @dry_run = dry_run
      @line_adapter = line_adapter
      @logger = logger
    end

    def call
      sent_student_ids = Set.new

      candidates.map do |candidate|
        if duplicate_recently_sent?(candidate)
          skipped_result(candidate, NotificationLog::DUPLICATE_RECENTLY_SENT_MESSAGE)
        elsif auto_sent_today?(candidate.student) || sent_student_ids.include?(candidate.student.id)
          skipped_result(candidate, "auto_daily_limit")
        elsif dry_run?
          Result.new(candidate: candidate, status: "previewed", message: "dry_run")
        else
          result = dispatch(candidate)
          sent_student_ids << candidate.student.id if result.log&.status == "sent"
          result
        end
      end
    end

    def candidates
      @candidates ||= (inactive_candidates + assignment_due_candidates + assignment_overdue_candidates)
        .sort_by { |candidate| [priority_for(candidate.notification_type), candidate.student.id, candidate.assignment&.id.to_i] }
    end

    def summary
      Summary.new(
        inactive_count: inactive_candidates.count,
        due_tomorrow_count: assignment_due_candidates.count,
        overdue_count: assignment_overdue_candidates.count
      )
    end

    def dry_run?
      @dry_run
    end

    private

    def inactive_candidates
      @inactive_candidates ||= line_connected_students.filter_map do |student|
        last_reaction_at = last_reaction_at_by_student_id[student.id]
        next if last_reaction_at.present? && last_reaction_at > INACTIVE_THRESHOLD.ago

        build_candidate(
          student: student,
          notification_type: INACTIVE_TYPE,
          reason: "3日以上未反応",
          title: "#{student.display_name}さんへ練習リマインド",
          message: template_body_for(student, INACTIVE_TYPE) || FALLBACK_MESSAGES.fetch(INACTIVE_TYPE),
          recommended_action: "今日やることを1つだけ開く",
          level: "normal"
        )
      end
    end

    def assignment_due_candidates
      @assignment_due_candidates ||= open_assignments.where(due_on: Date.current.tomorrow).includes(:learning_student).map do |assignment|
        student = assignment.learning_student
        build_assignment_candidate(
          assignment: assignment,
          student: student,
          notification_type: DUE_TYPE,
          reason: "課題期限前日",
          message: template_body_for(student, DUE_TYPE) || FALLBACK_MESSAGES.fetch(DUE_TYPE),
          level: "info"
        )
      end
    end

    def assignment_overdue_candidates
      @assignment_overdue_candidates ||= open_assignments.where("due_on < ?", Date.current).includes(:learning_student).map do |assignment|
        student = assignment.learning_student
        build_assignment_candidate(
          assignment: assignment,
          student: student,
          notification_type: OVERDUE_TYPE,
          reason: "課題期限超過",
          message: template_body_for(student, OVERDUE_TYPE) || FALLBACK_MESSAGES.fetch(OVERDUE_TYPE),
          level: "strong"
        )
      end
    end

    def build_assignment_candidate(assignment:, student:, notification_type:, reason:, message:, level:)
      build_candidate(
        student: student,
        notification_type: notification_type,
        reason: reason,
        title: assignment.title,
        message: message,
        recommended_action: assignment.due_on ? "期限: #{I18n.l(assignment.due_on, format: :short)}" : nil,
        assignment: assignment,
        level: level
      )
    end

    def build_candidate(student:, notification_type:, reason:, title:, message:, recommended_action:, level:, assignment: nil)
      Candidate.new(
        student: student,
        notification_type: notification_type,
        reason: reason,
        message: message,
        title: title,
        recommended_action: recommended_action,
        assignment: assignment,
        level: level,
        generated_at: Time.current
      )
    end

    def dispatch(candidate)
      log = create_log(candidate, status: "previewed")
      dispatcher.dispatch_log(log)
      Result.new(candidate: candidate, log: log.reload, status: log.status, message: log.error_message)
    end

    def skipped_result(candidate, message)
      log = create_log(candidate, status: "skipped", error_message: message) unless dry_run?
      Result.new(candidate: candidate, log: log, status: "skipped", message: message)
    end

    def create_log(candidate, status:, error_message: nil)
      NotificationLog.create!(
        customer: @customer,
        learning_student: candidate.student,
        notification_type: candidate.notification_type,
        level: candidate.level,
        delivery_channel: "line",
        status: status,
        title: candidate.title,
        message: candidate.message,
        recommended_action: candidate.recommended_action,
        generated_at: candidate.generated_at,
        error_message: error_message,
        metadata: log_metadata(candidate)
      )
    end

    def log_metadata(candidate)
      {
        reason: candidate.reason,
        assignment_id: candidate.assignment&.id,
        due_on: candidate.assignment&.due_on,
        source: "Learning::AutoReminderService"
      }.compact
    end

    def duplicate_recently_sent?(candidate)
      NotificationLog.recently_sent_duplicate?(
        customer: @customer,
        learning_student: candidate.student,
        notification_type: candidate.notification_type,
        since_time: DEDUPE_WINDOW.ago
      )
    end

    def auto_sent_today?(student)
      NotificationLog.auto_reminder_sent_today?(
        customer: @customer,
        learning_student: student,
        since_time: DEDUPE_WINDOW.ago
      )
    end

    def line_connected_students
      @line_connected_students ||= @customer.learning_students
        .active
        .joins(:learning_line_connections)
        .merge(LineConnection.connected)
        .distinct
        .to_a
    end

    def open_assignments
      @open_assignments ||= @customer.learning_assignments
        .where(status: LearningAssignment::OPEN_STATUSES, learning_student_id: line_connected_students.map(&:id))
    end

    def last_reaction_at_by_student_id
      @last_reaction_at_by_student_id ||= @customer.learning_notification_logs
        .where(learning_student_id: line_connected_students.map(&:id), reaction_received: true)
        .where.not(reacted_at: nil)
        .group(:learning_student_id)
        .maximum(:reacted_at)
    end

    def template_body_for(student, notification_type)
      categories = template_categories_for(student, notification_type)
      templates = @customer.learning_line_message_templates.active
        .where(category: categories)
        .order(updated_at: :desc)
        .to_a
      template = templates.min_by { |item| categories.index(item.category) || categories.size }
      template&.body
    end

    def template_categories_for(student, notification_type)
      categories = []
      categories << "beginner" if beginner_student?(student) && LearningLineMessageTemplate::CATEGORIES.include?("beginner")
      categories << if [DUE_TYPE, OVERDUE_TYPE].include?(notification_type)
                      "assignment"
                    else
                      "followup"
                    end

      categories
    end

    def beginner_student?(student)
      student.respond_to?(:tutorial_completed?) && !student.tutorial_completed?
    end

    def priority_for(notification_type)
      {
        OVERDUE_TYPE => 0,
        DUE_TYPE => 1,
        INACTIVE_TYPE => 2
      }.fetch(notification_type, 99)
    end

    def dispatcher
      @dispatcher ||= NotificationDispatcher.new(@customer, channels: [:line], line_adapter: @line_adapter)
    end
  end
end
