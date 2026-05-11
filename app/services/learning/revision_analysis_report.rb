module Learning
  class RevisionAnalysisReport
    TROUBLED_TRAINING_LIMIT = 5
    STRUGGLING_STUDENT_LIMIT = 5
    RECENT_REVISIONS_LIMIT = 10

    IMPROVEMENT_HINT = "差し戻しが多い場合、達成基準やチェック方法を具体化しましょう。".freeze
    FOLLOWUP_HINT = "個別に声をかけて、どこで止まっているか確認しましょう。".freeze

    TroubledTraining = Struct.new(
      :training_title,
      :revision_count,
      :student_count,
      :latest_comment,
      :improvement_hint,
      keyword_init: true
    )

    StrugglingStudent = Struct.new(
      :student,
      :revision_count,
      :training_count,
      :last_revised_at,
      :followup_hint,
      keyword_init: true
    )

    RecentRevision = Struct.new(
      :history,
      :student,
      :training_title,
      :assignment,
      keyword_init: true
    )

    def initialize(customer)
      @customer = customer
    end

    def troubled_trainings
      @troubled_trainings ||= build_troubled_trainings
    end

    def struggling_students
      @struggling_students ||= build_struggling_students
    end

    def recent_revisions
      @recent_revisions ||= build_recent_revisions
    end

    def any_data?
      revision_histories.any?
    end

    private

    def revision_histories
      @revision_histories ||= LearningAssignmentReviewHistory
        .where(learning_assignment_id: customer_assignment_ids, action: "revision_requested")
        .includes(learning_assignment: [:learning_student, { learning_student_training: :learning_training_master }])
        .order(created_at: :desc)
        .to_a
    end

    def customer_assignment_ids
      @customer.learning_assignments.select(:id)
    end

    def build_troubled_trainings
      training_groups = revision_histories
        .select { |h| h.learning_assignment.learning_student_training_id.present? }
        .group_by { |h| training_group_key(h) }

      training_groups.map do |_key, histories|
        training = histories.first.learning_assignment.learning_student_training
        training_title = training.title.presence || "タイトルなし"
        student_ids = histories.map { |h| h.learning_assignment.learning_student_id }.uniq
        latest_comment = histories.find { |h| h.comment.present? }&.comment

        TroubledTraining.new(
          training_title: training_title,
          revision_count: histories.size,
          student_count: student_ids.size,
          latest_comment: latest_comment,
          improvement_hint: IMPROVEMENT_HINT
        )
      end
        .sort_by { |item| [-item.revision_count, item.training_title.to_s] }
        .first(TROUBLED_TRAINING_LIMIT)
    end

    def training_group_key(history)
      training = history.learning_assignment.learning_student_training
      master_id = training.learning_training_master_id
      master_id.present? ? "master-#{master_id}" : "training-#{training.id}"
    end

    def build_struggling_students
      student_groups = revision_histories.group_by do |h|
        h.learning_assignment.learning_student_id
      end

      student_groups.map do |_student_id, histories|
        student = histories.first.learning_assignment.learning_student
        training_ids = histories
          .map { |h| h.learning_assignment.learning_student_training_id }
          .compact
          .uniq
        last_revised_at = histories.map(&:created_at).max

        StrugglingStudent.new(
          student: student,
          revision_count: histories.size,
          training_count: training_ids.size,
          last_revised_at: last_revised_at,
          followup_hint: FOLLOWUP_HINT
        )
      end
        .sort_by { |item| [-item.revision_count, item.student.display_name.to_s] }
        .first(STRUGGLING_STUDENT_LIMIT)
    end

    def build_recent_revisions
      revision_histories
        .select { |h| h.comment.present? }
        .first(RECENT_REVISIONS_LIMIT)
        .map do |history|
          assignment = history.learning_assignment
          student = assignment.learning_student
          training = assignment.learning_student_training
          training_title = training&.title.presence || assignment.title

          RecentRevision.new(
            history: history,
            student: student,
            training_title: training_title,
            assignment: assignment
          )
        end
    end
  end
end
