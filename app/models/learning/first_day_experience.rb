module Learning
  class FirstDayExperience
    TeacherAction = Struct.new(:key, :title, :body, :cta_label, :cta_path, keyword_init: true)
    TodayTask = Struct.new(:training, :title, :duration_label, :reason, :cta_anchor, :empty, keyword_init: true) do
      def empty?
        empty
      end
    end

    PART_RECOMMENDATIONS = {
      "vocal" => ["発声", "リズム"],
      "guitar" => ["コード", "ピッキング"],
      "bass" => ["リズムキープ", "ルート音"],
      "drums" => ["リズムキープ", "テンポ安定"],
      "keyboard" => ["コード", "両手の安定"],
      "band" => ["リズム", "合奏の入り"]
    }.freeze

    PART_REASONS = {
      "vocal" => "声の出だしと音程が安定します",
      "guitar" => "コードチェンジがなめらかになります",
      "bass" => "バンド全体の土台が安定します",
      "drums" => "テンポがぶれにくくなります",
      "keyboard" => "和音とリズムの支えが強くなります",
      "band" => "全員で合わせる力が育ちます"
    }.freeze

    def self.teacher_action(customer, routes:)
      new(customer: customer, routes: routes).teacher_action
    end

    def self.weekly_progress_points(customer)
      new(customer: customer).weekly_progress_points
    end

    def self.today_task(student)
      new(student: student).today_task
    end

    def self.feedback(student, streak_count:)
      new(student: student).feedback(streak_count: streak_count)
    end

    def self.recommendations_for(student)
      new(student: student).recommendations_for_student
    end

    def initialize(customer: nil, routes: nil, student: nil)
      @customer = customer
      @routes = routes
      @student = student
    end

    def teacher_action
      if active_student_count.zero?
        return TeacherAction.new(
          key: :students,
          title: "生徒を登録しよう",
          body: "最初の1人を登録すると、生徒専用ポータルと練習割当を始められます。",
          cta_label: "生徒を追加",
          cta_path: @routes.new_learning_student_path
        )
      end

      if school_group_count.zero?
        return TeacherAction.new(
          key: :groups,
          title: "グループを作ろう",
          body: "学校・学年・バンド単位でまとめると、進捗確認と案内が迷いません。",
          cta_label: "グループを作成",
          cta_path: @routes.new_learning_school_group_path
        )
      end

      if assignment_count.zero?
        return TeacherAction.new(
          key: :assignments,
          title: "トレーニングを割り当てよう",
          body: "生徒がログインしてすぐ動けるよう、まず1つだけ練習を渡しましょう。",
          cta_label: "生徒を選ぶ",
          cta_path: @routes.learning_students_path
        )
      end

      if unvisited_student_count.positive?
        return TeacherAction.new(
          key: :portal_guidance,
          title: "生徒に案内しよう",
          body: "まだポータルを開いていない生徒がいます。URLを共有して初回ログインまで進めましょう。",
          cta_label: "案内する生徒を見る",
          cta_path: @routes.learning_students_path
        )
      end

      if progress_log_count.zero?
        return TeacherAction.new(
          key: :first_week,
          title: "まず1週間やってみよう",
          body: "課題は届いています。今週は生徒に1つ練習してもらい、最初の記録を待ちましょう。",
          cta_label: "進捗ログを確認",
          cta_path: @routes.learning_progress_logs_path
        )
      end

      TeacherAction.new(
        key: :reflection,
        title: "今週の振り返りをしよう",
        body: "取り組みが見え始めています。達成率と記録数を見て、次の一言を決めましょう。",
        cta_label: "進捗を確認",
        cta_path: @routes.learning_progress_logs_path
      )
    end

    def weekly_progress_points
      dates = (6.days.ago.to_date..Date.current).to_a
      counts = @customer.learning_progress_logs
        .where(practiced_on: dates.first..dates.last)
        .group(:practiced_on)
        .count

      dates.map do |date|
        { date: date, label: date.strftime("%-m/%-d"), count: counts[date].to_i }
      end
    end

    def today_task
      training = student_trainings.find { |item| incomplete_training?(item) }
      return empty_today_task unless training

      TodayTask.new(
        training: training,
        title: training.title,
        duration_label: duration_for(training),
        reason: PART_REASONS.fetch(training.part.to_s, "今日の練習が次の成長につながります"),
        cta_anchor: "training-#{training.id}",
        empty: false
      )
    end

    def feedback(streak_count:)
      completed_count = student_trainings.count { |item| !incomplete_training?(item) }
      return "まずは1つやってみよう！" if completed_count.zero?
      return "いいペース！このまま続けよう" if streak_count.to_i >= 3
      return "かなり順調！次のレベルに挑戦" if achievement_rate >= 70

      "少しずつでOK！積み重ねが大事"
    end

    def recommendations_for_student
      part = @student&.main_part.presence || "band"
      PART_RECOMMENDATIONS.fetch(part.to_s, PART_RECOMMENDATIONS["band"])
    end

    private

    def active_student_count
      @active_student_count ||= @customer.learning_students.active.count
    end

    def school_group_count
      @school_group_count ||= @customer.learning_school_groups.count
    end

    def assignment_count
      @assignment_count ||= @customer.learning_student_trainings.count
    end

    def unvisited_student_count
      @unvisited_student_count ||= @customer.learning_students
        .active
        .left_joins(:learning_portal_accesses)
        .where(learning_portal_accesses: { id: nil })
        .distinct
        .count
    end

    def progress_log_count
      @progress_log_count ||= @customer.learning_progress_logs.count
    end

    def student_trainings
      @student_trainings ||= @student.learning_student_trainings.ordered.to_a
    end

    def incomplete_training?(training)
      training.status != "achieved" && !training.star?
    end

    def achievement_rate
      return 0 if student_trainings.empty?

      completed_count = student_trainings.count { |item| !incomplete_training?(item) }
      ((completed_count.to_f / student_trainings.count) * 100).round
    end

    def duration_for(training)
      case training.level
      when "基礎"
        "5分"
      when "安定"
        "8分"
      when "応用"
        "10分"
      else
        "15分"
      end
    end

    def empty_today_task
      TodayTask.new(
        training: nil,
        title: "先生が準備中です",
        duration_label: nil,
        reason: "課題が届いたら、ここに今日やる練習が表示されます",
        cta_anchor: nil,
        empty: true
      )
    end
  end
end
