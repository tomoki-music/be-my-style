module Learning
  class OnboardingStatus
    Step = Struct.new(:key, :title, :body, :completed, :cta_label, :cta_path, keyword_init: true)

    attr_reader :student_count, :school_group_count, :assignment_count, :portal_access_count, :progress_log_count

    def initialize(customer, routes:)
      @customer = customer
      @routes = routes
      @student_count = customer.learning_students.active.count
      @school_group_count = customer.learning_school_groups.count
      @assignment_count = customer.learning_student_trainings.count
      @portal_access_count = LearningPortalAccess.joins(:learning_student)
        .where(learning_students: { customer_id: customer.id })
        .count
      @progress_log_count = customer.learning_progress_logs.count
    end

    def steps
      [
        Step.new(
          key: :students,
          title: "生徒を登録する",
          body: "まず部員を1人登録すると、個別の課題とポータルURLを用意できます。",
          completed: student_count.positive?,
          cta_label: "生徒を追加",
          cta_path: @routes.new_learning_student_path
        ),
        Step.new(
          key: :groups,
          title: "グループを作成する",
          body: "学校や学年でまとめると、ランキングや進捗確認が見やすくなります。",
          completed: school_group_count.positive?,
          cta_label: "グループを作成",
          cta_path: @routes.new_learning_school_group_path
        ),
        Step.new(
          key: :assignments,
          title: "トレーニングを割り当てる",
          body: "生徒のパートに合う最初の練習を1つ渡して、初日から動ける状態にします。",
          completed: assignment_count.positive?,
          cta_label: "生徒を選ぶ",
          cta_path: @routes.learning_students_path
        ),
        Step.new(
          key: :portal_guidance,
          title: "生徒にログイン方法を案内する",
          body: "生徒詳細のポータルURLを共有すると、生徒は自分の課題を確認できます。",
          completed: portal_access_count.positive? || progress_log_count.positive?,
          cta_label: "案内する生徒を選ぶ",
          cta_path: @routes.learning_students_path
        ),
        Step.new(
          key: :operation,
          title: "運用開始する",
          body: "最初の練習記録が入ると、達成率・努力ポイント・ランキングが育ち始めます。",
          completed: progress_log_count.positive?,
          cta_label: "進捗ログを見る",
          cta_path: @routes.learning_progress_logs_path
        )
      ]
    end

    def completed?
      steps.all?(&:completed)
    end

    def completed_count
      steps.count(&:completed)
    end

    def total_count
      steps.count
    end
  end
end
