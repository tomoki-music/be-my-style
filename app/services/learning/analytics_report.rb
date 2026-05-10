module Learning
  class AnalyticsReport
    PERIODS = {
      "this_week" => "今週",
      "last_week" => "先週",
      "30days" => "直近30日"
    }.freeze

    Summary = Struct.new(
      :assignment_submission_rate,
      :line_reaction_rate,
      :progress_log_count,
      :unsubmitted_count,
      :inactive_student_count,
      :assignment_count,
      :line_sent_count,
      :line_reaction_count,
      keyword_init: true
    )

    StudentSummary = Struct.new(
      :student,
      :submission_rate,
      :reaction_rate,
      :last_reaction_at,
      :status,
      :status_label,
      :assignment_count,
      :line_sent_count,
      keyword_init: true
    ) do
      def follow_up?
        status == :follow_up
      end

      def watch?
        status == :watch
      end
    end

    AssignmentSummary = Struct.new(
      :title,
      :completion_rate,
      :completed_count,
      :total_count,
      :unsubmitted_count,
      keyword_init: true
    )

    AtRiskStudent = Struct.new(
      :student,
      :completion_rate,
      :inactive_days,
      :pending_assignments,
      :last_reaction_at,
      :line_connected,
      keyword_init: true
    )

    attr_reader :customer, :period, :date_range, :time_range

    def initialize(customer, period: "this_week", reference_time: Time.current, students: nil)
      @customer = customer
      @period = PERIODS.key?(period.to_s) ? period.to_s : "this_week"
      @reference_time = reference_time
      @students = students
      @date_range = build_date_range
      @time_range = @date_range.begin.beginning_of_day..@date_range.end.end_of_day
    end

    def period_label
      PERIODS.fetch(period)
    end

    def summary
      @summary ||= Summary.new(
        assignment_submission_rate: percentage(completed_assignments.count, assignments.count),
        line_reaction_rate: percentage(line_reaction_logs.count, line_sent_logs.count),
        progress_log_count: progress_logs.count,
        unsubmitted_count: assignments.count { |assignment| open_assignment?(assignment) },
        inactive_student_count: student_summaries.count { |item| stale_reaction?(item.last_reaction_at) },
        assignment_count: assignments.count,
        line_sent_count: line_sent_logs.count,
        line_reaction_count: line_reaction_logs.count
      )
    end

    def student_summaries
      @student_summaries ||= active_students.map do |student|
        student_assignments = assignments_by_student_id.fetch(student.id, [])
        student_line_logs = line_logs_by_student_id.fetch(student.id, [])
        last_reaction_at = last_reaction_at_by_student_id[student.id]
        submission_rate = percentage(
          student_assignments.count { |assignment| assignment.status == "completed" },
          student_assignments.size
        )
        reaction_rate = percentage(student_line_logs.count { |log| log.reaction_received? }, student_line_logs.size)
        status = student_status(submission_rate, last_reaction_at)

        StudentSummary.new(
          student: student,
          submission_rate: submission_rate,
          reaction_rate: reaction_rate,
          last_reaction_at: last_reaction_at,
          status: status,
          status_label: status_label(status),
          assignment_count: student_assignments.size,
          line_sent_count: student_line_logs.size
        )
      end
    end

    def assignment_summaries
      @assignment_summaries ||= assignments
        .group_by { |assignment| assignment_group_key(assignment) }
        .values
        .map { |group| build_assignment_summary(group) }
        .sort_by { |item| [-item.completion_rate, item.title.to_s] }
    end

    def at_risk_students
      @at_risk_students ||= student_summaries
        .select { |item| item.submission_rate < 30 || stale_reaction?(item.last_reaction_at) }
        .map { |item| build_at_risk_student(item) }
    end

    private

    def build_date_range
      date = @reference_time.to_date

      case period
      when "last_week"
        (date - 7).all_week
      when "30days"
        (date - 29.days)..date
      else
        date.all_week
      end
    end

    def active_students
      @active_students ||= begin
        scope = @students || customer.learning_students.active.ordered
        scope.to_a
      end
    end

    def active_student_ids
      @active_student_ids ||= active_students.map(&:id)
    end

    def assignments
      @assignments ||= begin
        base = customer.learning_assignments.where(learning_student_id: active_student_ids)
        scoped = base.where(created_at: time_range)
          .or(base.where(completed_at: time_range))
          .or(base.where(status: LearningAssignment::OPEN_STATUSES))
        group_keys = scoped.where.not(assignment_group_key: nil).distinct.pluck(:assignment_group_key)
        sibling_assignments = group_keys.any? ? base.where(assignment_group_key: group_keys) : base.none
        base.where(id: scoped.select(:id)).or(sibling_assignments).to_a
      end
    end

    def completed_assignments
      @completed_assignments ||= assignments.select { |assignment| assignment.status == "completed" }
    end

    def progress_logs
      @progress_logs ||= customer.learning_progress_logs
        .where(learning_student_id: active_student_ids, practiced_on: date_range)
    end

    def line_sent_logs
      @line_sent_logs ||= customer.learning_notification_logs
        .where(learning_student_id: active_student_ids,
               delivery_channel: "line",
               status: "sent",
               generated_at: time_range)
        .to_a
    end

    def line_reaction_logs
      @line_reaction_logs ||= line_sent_logs.select(&:reaction_received?)
    end

    def last_reaction_at_by_student_id
      @last_reaction_at_by_student_id ||= customer.learning_notification_logs
        .where(learning_student_id: active_student_ids, reaction_received: true)
        .where.not(reacted_at: nil)
        .group(:learning_student_id)
        .maximum(:reacted_at)
    end

    def assignments_by_student_id
      @assignments_by_student_id ||= assignments.group_by(&:learning_student_id)
    end

    def line_logs_by_student_id
      @line_logs_by_student_id ||= line_sent_logs.group_by(&:learning_student_id)
    end

    def assignment_group_key(assignment)
      assignment.assignment_group_key.presence || "assignment-#{assignment.id}"
    end

    def open_assignment?(assignment)
      LearningAssignment::OPEN_STATUSES.include?(assignment.status)
    end

    def build_assignment_summary(group)
      title = group.max_by(&:created_at).title
      completed_count = group.count { |assignment| assignment.status == "completed" }
      total_count = group.size

      AssignmentSummary.new(
        title: title,
        completion_rate: percentage(completed_count, total_count),
        completed_count: completed_count,
        total_count: total_count,
        unsubmitted_count: total_count - completed_count
      )
    end

    def build_at_risk_student(item)
      student_assignments = assignments_by_student_id.fetch(item.student.id, [])

      AtRiskStudent.new(
        student: item.student,
        completion_rate: item.submission_rate,
        inactive_days: inactive_days(item.last_reaction_at),
        pending_assignments: student_assignments.count { |assignment| open_assignment?(assignment) },
        last_reaction_at: item.last_reaction_at,
        line_connected: item.student.line_connected?
      )
    end

    def student_status(submission_rate, last_reaction_at)
      return :follow_up if stale_reaction?(last_reaction_at) || submission_rate < 30
      return :good if submission_rate >= 70

      :watch
    end

    def stale_reaction?(last_reaction_at)
      last_reaction_at.blank? || last_reaction_at < 7.days.ago(@reference_time)
    end

    def inactive_days(last_reaction_at)
      return nil if last_reaction_at.blank?

      ((@reference_time.to_date - last_reaction_at.to_date).to_i).clamp(0, Float::INFINITY)
    end

    def status_label(status)
      {
        good: "順調",
        watch: "様子見",
        follow_up: "要フォロー"
      }.fetch(status)
    end

    def percentage(numerator, denominator)
      return 0 if denominator.to_i.zero?

      ((numerator.to_f / denominator) * 100).round
    end
  end
end
