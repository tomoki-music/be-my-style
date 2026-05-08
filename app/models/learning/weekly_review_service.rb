module Learning
  class WeeklyReviewService
    StudentHighlight = Struct.new(:student, :count, :label, keyword_init: true)
    Intervention = Struct.new(:student, :last_practiced_on, :days_idle, keyword_init: true)
    Review = Struct.new(:top_students, :growth_students, :stagnant_students, keyword_init: true)

    def initialize(customer, students:)
      @customer = customer
      @students = students.to_a
      @student_ids = @students.map(&:id)
      @students_by_id = @students.index_by(&:id)
    end

    def build
      Review.new(
        top_students: top_students,
        growth_students: growth_students,
        stagnant_students: stagnant_students
      )
    end

    private

    def top_students
      this_week_counts
        .sort_by { |_, count| -count }
        .first(3)
        .filter_map do |student_id, count|
          student = @students_by_id[student_id]
          next unless student

          StudentHighlight.new(student: student, count: count, label: "#{count}件")
        end
    end

    def growth_students
      @student_ids
        .map { |id| [id, this_week_counts[id].to_i - last_week_counts[id].to_i] }
        .select { |_, delta| delta.positive? }
        .sort_by { |_, delta| -delta }
        .first(3)
        .filter_map do |student_id, delta|
          student = @students_by_id[student_id]
          next unless student

          StudentHighlight.new(student: student, count: delta, label: "+#{delta}件")
        end
    end

    def stagnant_students
      @students
        .map do |student|
          last_date = last_practiced_on_by_student[student.id]
          days_idle = last_date ? (Date.current - last_date).to_i : nil
          Intervention.new(student: student, last_practiced_on: last_date, days_idle: days_idle)
        end
        .select { |item| item.last_practiced_on.nil? || item.days_idle >= 3 }
        .sort_by { |item| [item.last_practiced_on ? 1 : 0, item.last_practiced_on || Date.new(1900, 1, 1)] }
        .first(3)
    end

    def this_week_counts
      @this_week_counts ||= counts_for(Date.current.all_week)
    end

    def last_week_counts
      @last_week_counts ||= counts_for(1.week.ago.to_date.all_week)
    end

    def counts_for(range)
      return {} if @student_ids.empty?

      @customer.learning_progress_logs
        .where(learning_student_id: @student_ids, practiced_on: range)
        .group(:learning_student_id)
        .count
    end

    def last_practiced_on_by_student
      return @last_practiced_on_by_student if defined?(@last_practiced_on_by_student)

      @last_practiced_on_by_student = if @student_ids.empty?
        {}
      else
        @customer.learning_progress_logs
          .where(learning_student_id: @student_ids)
          .group(:learning_student_id)
          .maximum(:practiced_on)
      end
    end
  end
end
