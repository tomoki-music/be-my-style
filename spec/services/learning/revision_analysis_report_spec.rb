require "rails_helper"

RSpec.describe Learning::RevisionAnalysisReport do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:other_teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:student_a) { create(:learning_student, customer: teacher, name: "生徒A") }
  let(:student_b) { create(:learning_student, customer: teacher, name: "生徒B") }
  let(:other_student) { create(:learning_student, customer: other_teacher, name: "他校生徒") }

  subject(:report) { described_class.new(teacher) }

  def create_revision_history(assignment:, comment: "テンポを確認してみよう", created_at: Time.current)
    assignment.review_histories.create!(
      action: "revision_requested",
      reviewer: teacher,
      comment: comment,
      created_at: created_at
    )
  end

  def create_training_assignment(student:, training_title: "コード練習")
    master = create(:learning_training_master, customer: teacher, judge_type: "teacher",
                                               title: training_title)
    training = create(:learning_student_training, customer: teacher,
                                                  learning_student: student,
                                                  learning_training_master: master,
                                                  title: nil)
    training.learning_assignments.first
  end

  describe "#any_data?" do
    it "差し戻し履歴がない場合はfalseを返すこと" do
      expect(report.any_data?).to be false
    end

    it "差し戻し履歴がある場合はtrueを返すこと" do
      assignment = create_training_assignment(student: student_a)
      create_revision_history(assignment: assignment)

      expect(report.any_data?).to be true
    end

    it "他顧問の差し戻し履歴はカウントしないこと" do
      other_assignment = create(:learning_assignment, customer: other_teacher,
                                                      learning_student: other_student)
      create_revision_history(assignment: other_assignment)

      expect(report.any_data?).to be false
    end
  end

  describe "#troubled_trainings" do
    it "差し戻し回数の多いトレーニングを降順で返すこと" do
      assignment_hard = create_training_assignment(student: student_a, training_title: "難しいトレーニング")
      assignment_easy = create_training_assignment(student: student_a, training_title: "簡単なトレーニング")
      3.times { create_revision_history(assignment: assignment_hard) }
      1.times { create_revision_history(assignment: assignment_easy) }

      result = report.troubled_trainings
      expect(result.first.training_title).to eq("難しいトレーニング")
      expect(result.first.revision_count).to eq(3)
      expect(result.second.training_title).to eq("簡単なトレーニング")
      expect(result.second.revision_count).to eq(1)
    end

    it "同じマスターを持つ複数生徒の対象生徒数を正しく集計すること" do
      master = create(:learning_training_master, customer: teacher, title: "コード練習",
                                                 judge_type: "teacher")
      training_a = create(:learning_student_training, customer: teacher,
                                                      learning_student: student_a,
                                                      learning_training_master: master,
                                                      title: nil)
      training_b = create(:learning_student_training, customer: teacher,
                                                      learning_student: student_b,
                                                      learning_training_master: master,
                                                      title: nil)
      create_revision_history(assignment: training_a.learning_assignments.first)
      create_revision_history(assignment: training_b.learning_assignments.first)

      result = report.troubled_trainings
      expect(result.first.student_count).to eq(2)
    end

    it "最大5件を返すこと" do
      6.times do |i|
        assignment = create_training_assignment(student: student_a, training_title: "トレーニング#{i}")
        create_revision_history(assignment: assignment)
      end

      expect(report.troubled_trainings.size).to be <= 5
    end

    it "他顧問のデータを含めないこと" do
      other_assignment = create(:learning_assignment, customer: other_teacher,
                                                      learning_student: other_student)
      create_revision_history(assignment: other_assignment)

      expect(report.troubled_trainings).to be_empty
    end

    it "改善ヒントを含むこと" do
      assignment = create_training_assignment(student: student_a)
      create_revision_history(assignment: assignment)

      expect(report.troubled_trainings.first.improvement_hint).to eq(Learning::RevisionAnalysisReport::IMPROVEMENT_HINT)
    end

    it "トレーニング紐付きでない課題は除外すること" do
      plain_assignment = create(:learning_assignment, customer: teacher, learning_student: student_a)
      create_revision_history(assignment: plain_assignment)

      expect(report.troubled_trainings).to be_empty
    end

    it "最新コメントを含むこと" do
      assignment = create_training_assignment(student: student_a)
      create_revision_history(assignment: assignment, comment: "テンポを確認してみよう",
                              created_at: 2.hours.ago)
      create_revision_history(assignment: assignment, comment: "音量も意識してみよう",
                              created_at: 1.hour.ago)

      expect(report.troubled_trainings.first.latest_comment).to eq("音量も意識してみよう")
    end
  end

  describe "#struggling_students" do
    it "差し戻し回数の多い生徒を降順で返すこと" do
      assignment_a1 = create_training_assignment(student: student_a)
      assignment_a2 = create_training_assignment(student: student_a, training_title: "別の練習")
      assignment_b = create_training_assignment(student: student_b)
      3.times { create_revision_history(assignment: assignment_a1) }
      create_revision_history(assignment: assignment_a2)
      create_revision_history(assignment: assignment_b)

      result = report.struggling_students
      expect(result.first.student.name).to eq("生徒A")
      expect(result.first.revision_count).to eq(4)
      expect(result.second.student.name).to eq("生徒B")
      expect(result.second.revision_count).to eq(1)
    end

    it "対象トレーニング数を正しく集計すること" do
      assignment_1 = create_training_assignment(student: student_a, training_title: "練習1")
      assignment_2 = create_training_assignment(student: student_a, training_title: "練習2")
      create_revision_history(assignment: assignment_1)
      create_revision_history(assignment: assignment_2)

      result = report.struggling_students
      expect(result.first.training_count).to eq(2)
    end

    it "最大5件を返すこと" do
      6.times do |i|
        student = create(:learning_student, customer: teacher, name: "生徒#{i}")
        assignment = create_training_assignment(student: student)
        create_revision_history(assignment: assignment)
      end

      expect(report.struggling_students.size).to be <= 5
    end

    it "他顧問のデータを含めないこと" do
      other_assignment = create(:learning_assignment, customer: other_teacher,
                                                      learning_student: other_student)
      create_revision_history(assignment: other_assignment)

      expect(report.struggling_students).to be_empty
    end

    it "フォロー提案を含むこと" do
      assignment = create_training_assignment(student: student_a)
      create_revision_history(assignment: assignment)

      expect(report.struggling_students.first.followup_hint).to eq(Learning::RevisionAnalysisReport::FOLLOWUP_HINT)
    end

    it "最終差し戻し日時を正しく返すこと" do
      assignment = create_training_assignment(student: student_a)
      create_revision_history(assignment: assignment, created_at: 3.days.ago)
      latest = create_revision_history(assignment: assignment, created_at: 1.day.ago)

      result = report.struggling_students.first
      expect(result.last_revised_at.to_i).to eq(latest.created_at.to_i)
    end
  end

  describe "#recent_revisions" do
    it "コメント付き差し戻しを新しい順で返すこと" do
      assignment = create_training_assignment(student: student_a)
      old_rev = create_revision_history(assignment: assignment, comment: "古いコメント",
                                        created_at: 2.days.ago)
      new_rev = create_revision_history(assignment: assignment, comment: "新しいコメント",
                                        created_at: 1.day.ago)

      result = report.recent_revisions
      expect(result.first.history).to eq(new_rev)
      expect(result.second.history).to eq(old_rev)
    end

    it "コメントなしの差し戻しは除外すること" do
      assignment = create_training_assignment(student: student_a)
      create_revision_history(assignment: assignment, comment: nil)
      with_comment = create_revision_history(assignment: assignment, comment: "コメントあり")

      result = report.recent_revisions
      expect(result.size).to eq(1)
      expect(result.first.history).to eq(with_comment)
    end

    it "最大10件を返すこと" do
      assignment = create_training_assignment(student: student_a)
      12.times { create_revision_history(assignment: assignment, comment: "コメント") }

      expect(report.recent_revisions.size).to be <= 10
    end

    it "他顧問のデータを含めないこと" do
      other_assignment = create(:learning_assignment, customer: other_teacher,
                                                      learning_student: other_student)
      create_revision_history(assignment: other_assignment, comment: "他顧問のコメント")

      expect(report.recent_revisions).to be_empty
    end

    it "student・training_title・assignmentを正しく返すこと" do
      assignment = create_training_assignment(student: student_a, training_title: "8分音符練習")
      create_revision_history(assignment: assignment, comment: "リズムを確認してみよう")

      result = report.recent_revisions.first
      expect(result.student).to eq(student_a)
      expect(result.training_title).to eq("8分音符練習")
      expect(result.assignment).to eq(assignment)
    end
  end
end
