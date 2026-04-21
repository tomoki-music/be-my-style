module Learning
  class DashboardBuilder
    StudentRow = Struct.new(
      :student,
      :parts,
      :progress_rate,
      :achievement_count,
      :total_count,
      :weekly_goal,
      :comment,
      :recent_star_count,
      :rank,
      :mvp,
      :weekly_mvp,
      keyword_init: true
    )

    def initialize(customer, school_group: nil)
      @customer = customer
      @school_group = school_group
    end

    def build
      students = student_scope
        .includes(:learning_school_group, :learning_student_parts, :learning_student_trainings, :learning_progress_logs)
        .ordered

      rows = students.map { |student| build_row(student) }
      ranked_rows = rank_rows(rows)
      filtered_trainings = students.flat_map(&:learning_student_trainings)

      OpenStruct.new(
        student_rows: ranked_rows,
        school_group: @school_group,
        overall_progress_rate: calculate_overall_progress_rate(ranked_rows),
        overall_achievement_count: ranked_rows.sum(&:achievement_count),
        part_stats: build_part_stats(filtered_trainings),
        recent_logs: recent_logs_scope.includes(:learning_student).recent_first.limit(8),
        top_recent_students: ranked_rows.sort_by { |row| [-row.recent_star_count, row.student.name] }.first(3),
        weekly_mvps: ranked_rows.select(&:weekly_mvp)
      )
    end

    private

    def student_scope
      scope = @customer.learning_students
      scope = scope.where(learning_school_group_id: @school_group.id) if @school_group.present?
      scope
    end

    def recent_logs_scope
      scope = @customer.learning_progress_logs
      return scope unless @school_group.present?

      scope.joins(:learning_student).where(learning_students: { learning_school_group_id: @school_group.id })
    end

    def build_row(student)
      trainings = student.learning_student_trainings.sort_by { |training| [training.position, training.created_at] }
      total_count = trainings.size
      achievement_count = trainings.count(&:star?)
      progress_rate = total_count.zero? ? 0 : ((achievement_count.to_f / total_count) * 100).round
      weekly_goal = trainings.map(&:weekly_goal).find(&:present?)
      comment = trainings.map(&:teacher_comment).find(&:present?)
      recent_star_count = student.learning_progress_logs.count do |log|
        log.star? && log.practiced_on.present? && log.practiced_on >= 7.days.ago.to_date
      end

      StudentRow.new(
        student: student,
        parts: student.displayed_parts,
        progress_rate: progress_rate,
        achievement_count: achievement_count,
        total_count: total_count,
        weekly_goal: weekly_goal,
        comment: comment,
        recent_star_count: recent_star_count
      )
    end

    def rank_rows(rows)
      sorted_rows = rows.sort_by do |row|
        [-row.progress_rate, -row.achievement_count, row.student.name]
      end

      top_progress = sorted_rows.first&.progress_rate.to_i
      top_achievement = sorted_rows.first&.achievement_count.to_i
      top_recent = sorted_rows.map(&:recent_star_count).max.to_i

      sorted_rows.each_with_index.map do |row, index|
        row.rank = index + 1
        row.mvp = row.progress_rate == top_progress && row.achievement_count == top_achievement && row.total_count.positive?
        row.weekly_mvp = row.recent_star_count.positive? && row.recent_star_count == top_recent
        row
      end
    end

    def calculate_overall_progress_rate(rows)
      total_count = rows.sum(&:total_count)
      return 0 if total_count.zero?

      ((rows.sum(&:achievement_count).to_f / total_count) * 100).round
    end

    def build_part_stats(trainings)
      LearningCatalog::PARTS.keys.map do |part|
        part_trainings = trainings.select { |training| training.part == part }
        total_count = part_trainings.size
        achievement_count = part_trainings.count(&:star?)
        rate = total_count.zero? ? 0 : ((achievement_count.to_f / total_count) * 100).round

        {
          part: part,
          total_count: total_count,
          achievement_count: achievement_count,
          progress_rate: rate
        }
      end
    end
  end
end
