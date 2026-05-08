module Learning
  class ReminderService
    Reminder = Struct.new(:student, :stage, :days_idle, :message, :tone, keyword_init: true) do
      def active?
        stage.present?
      end
    end

    STAGES = {
      2 => { tone: "light", message: "少し間が空いています！1つだけやってみよう" },
      3 => { tone: "medium", message: "ここで戻ると差がつきます" },
      5 => { tone: "strong", message: "もう一度始めてみよう" }
    }.freeze

    def self.for_student(student, last_practiced_on: nil)
      new(student, last_practiced_on: last_practiced_on).reminder
    end

    def self.for_customer(customer)
      students = customer.learning_students.active.to_a
      last_practiced_on_by_student = customer.learning_progress_logs
        .where(learning_student_id: students.map(&:id))
        .group(:learning_student_id)
        .maximum(:practiced_on)

      students.filter_map do |student|
        reminder = for_student(student, last_practiced_on: last_practiced_on_by_student[student.id])
        reminder if reminder.active?
      end
    end

    def initialize(student, last_practiced_on: nil)
      @student = student
      @last_practiced_on = last_practiced_on
    end

    def reminder
      stage = stage_for(days_idle)
      payload = STAGES[stage]

      Reminder.new(
        student: @student,
        stage: stage,
        days_idle: days_idle,
        message: payload&.fetch(:message),
        tone: payload&.fetch(:tone)
      )
    end

    private

    def days_idle
      @days_idle ||= begin
        return nil unless @last_practiced_on

        (Date.current - @last_practiced_on).to_i
      end
    end

    def stage_for(value)
      return nil unless value
      return 5 if value >= 5
      return 3 if value >= 3
      return 2 if value >= 2

      nil
    end
  end
end
