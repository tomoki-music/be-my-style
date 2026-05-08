require "rails_helper"

RSpec.describe Learning::FirstDayExperience do
  let(:customer) { create(:customer, domain_name: "learning") }
  let(:routes) do
    double(
      new_learning_student_path: "/learning/students/new",
      new_learning_school_group_path: "/learning/school_groups/new",
      learning_students_path: "/learning/students",
      learning_progress_logs_path: "/learning/progress_logs"
    )
  end

  describe ".teacher_action" do
    it "生徒がいない場合は生徒登録を案内すること" do
      action = described_class.teacher_action(customer, routes: routes)

      expect(action.key).to eq(:students)
      expect(action.title).to eq("生徒を登録しよう")
      expect(action.cta_path).to eq("/learning/students/new")
    end

    it "グループがない場合はグループ作成を案内すること" do
      create(:learning_student, customer: customer)

      action = described_class.teacher_action(customer, routes: routes)

      expect(action.key).to eq(:groups)
      expect(action.title).to eq("グループを作ろう")
    end

    it "割当がない場合はトレーニング割当を案内すること" do
      group = create(:learning_school_group, customer: customer)
      create(:learning_student, customer: customer, learning_school_group: group)

      action = described_class.teacher_action(customer, routes: routes)

      expect(action.key).to eq(:assignments)
      expect(action.title).to eq("トレーニングを割り当てよう")
    end

    it "未ログイン生徒がいる場合は案内を促すこと" do
      group = create(:learning_school_group, customer: customer)
      student = create(:learning_student, customer: customer, learning_school_group: group)
      create(:learning_student_training, customer: customer, learning_student: student)

      action = described_class.teacher_action(customer, routes: routes)

      expect(action.key).to eq(:portal_guidance)
      expect(action.title).to eq("生徒に案内しよう")
    end

    it "進捗がない場合は1週間の運用を案内すること" do
      group = create(:learning_school_group, customer: customer)
      student = create(:learning_student, customer: customer, learning_school_group: group)
      create(:learning_student_training, customer: customer, learning_student: student)
      create(:learning_portal_access, learning_student: student)

      action = described_class.teacher_action(customer, routes: routes)

      expect(action.key).to eq(:first_week)
      expect(action.title).to eq("まず1週間やってみよう")
    end

    it "すべて揃った場合は振り返りを案内すること" do
      group = create(:learning_school_group, customer: customer)
      student = create(:learning_student, customer: customer, learning_school_group: group)
      training = create(:learning_student_training, customer: customer, learning_student: student)
      create(:learning_portal_access, learning_student: student)
      create(:learning_progress_log, customer: customer, learning_student: student,
                                   learning_student_training: training)

      action = described_class.teacher_action(customer, routes: routes)

      expect(action.key).to eq(:reflection)
      expect(action.title).to eq("今週の振り返りをしよう")
    end
  end

  describe ".weekly_progress_points" do
    it "直近7日分を0件の日も含めて返すこと" do
      student = create(:learning_student, customer: customer)
      create(:learning_progress_log, customer: customer, learning_student: student, practiced_on: Date.current)
      create(:learning_progress_log, customer: customer, learning_student: student, practiced_on: 2.days.ago.to_date)

      points = described_class.weekly_progress_points(customer)

      expect(points.size).to eq(7)
      expect(points.last[:date]).to eq(Date.current)
      expect(points.last[:count]).to eq(1)
      expect(points.map { |point| point[:count] }).to include(0)
    end
  end

  describe ".today_task" do
    it "最初の未完了トレーニングを返すこと" do
      student = create(:learning_student, customer: customer, main_part: "vocal")
      create(:learning_student_training, customer: customer, learning_student: student,
                                     status: "achieved", achievement_mark: "star", position: 1)
      training = create(:learning_student_training, customer: customer, learning_student: student,
                                                part: "vocal", title: "基礎リズム練習", position: 2)

      task = described_class.today_task(student)

      expect(task).not_to be_empty
      expect(task.training).to eq(training)
      expect(task.title).to eq("基礎リズム練習")
      expect(task.duration_label).to eq("5分")
      expect(task.reason).to include("安定")
    end

    it "割当がない場合は準備中を返すこと" do
      student = create(:learning_student, customer: customer)

      task = described_class.today_task(student)

      expect(task).to be_empty
      expect(task.title).to eq("先生が準備中です")
    end
  end

  describe ".feedback" do
    it "完了数が0の場合は最初の1つを促すこと" do
      student = create(:learning_student, customer: customer)
      create(:learning_student_training, customer: customer, learning_student: student)

      expect(described_class.feedback(student, streak_count: 0)).to eq("まずは1つやってみよう！")
    end

    it "継続日数が3日以上の場合は継続を促すこと" do
      student = create(:learning_student, customer: customer)
      create(:learning_student_training, customer: customer, learning_student: student,
                                     status: "achieved", achievement_mark: "star")

      expect(described_class.feedback(student, streak_count: 3)).to eq("いいペース！このまま続けよう")
    end

    it "達成率が高い場合は次レベル挑戦を促すこと" do
      student = create(:learning_student, customer: customer)
      create(:learning_student_training, customer: customer, learning_student: student,
                                     status: "achieved", achievement_mark: "star")
      create(:learning_student_training, customer: customer, learning_student: student,
                                     status: "achieved", achievement_mark: "star")
      create(:learning_student_training, customer: customer, learning_student: student,
                                     status: "achieved", achievement_mark: "star")
      create(:learning_student_training, customer: customer, learning_student: student)

      expect(described_class.feedback(student, streak_count: 1)).to eq("かなり順調！次のレベルに挑戦")
    end
  end

  describe ".recommendations_for" do
    it "生徒のパートに応じたおすすめを返すこと" do
      student = create(:learning_student, customer: customer, main_part: "drums")

      expect(described_class.recommendations_for(student)).to eq(["リズムキープ", "テンポ安定"])
    end
  end
end
