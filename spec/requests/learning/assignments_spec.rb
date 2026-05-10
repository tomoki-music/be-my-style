require "rails_helper"

RSpec.describe "Learning assignments", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:title) { "ライブ前基礎練習" }
  let(:description) { "・クロマチック\n・8ビート\n・コードチェンジ" }
  let(:due_on) { "2026-05-20" }

  before { sign_in teacher }

  describe "POST /learning/assignments" do
    it "複数生徒へassignmentを作成し通知ログを保存すること" do
      students = create_list(:learning_student, 2, customer: teacher)
      students.each_with_index { |student, index| create_connected_line(student, "UassignmentUser#{index}") }
      adapter = successful_adapter

      expect {
        post learning_assignments_path, params: assignment_params(student_ids: students.map(&:id))
      }.to change(LearningAssignment, :count).by(2)
        .and change(Learning::NotificationLog, :count).by(2)

      assignments = LearningAssignment.order(:created_at).last(2)
      logs = Learning::NotificationLog.order(:created_at).last(2)
      expect(response).to redirect_to(learning_students_path)
      expect(flash[:notice]).to include("配布：2件")
      expect(flash[:notice]).to include("LINE通知成功：2件")
      expect(assignments.map(&:learning_student)).to match_array(students)
      expect(assignments.map(&:status)).to all(eq("pending"))
      expect(assignments.map(&:due_on)).to all(eq(Date.parse(due_on)))
      expect(logs.map(&:notification_type)).to all(eq("assignment_created"))
      expect(logs.map(&:status)).to all(eq("sent"))
      expect(logs.map(&:title)).to all(eq(title))
      expect(adapter).to have_received(:deliver).twice
    end

    it "未連携生徒にも課題を作りLINE通知はskippedにすること" do
      student = create(:learning_student, customer: teacher)
      successful_adapter

      expect {
        post learning_assignments_path, params: assignment_params(student_ids: [student.id])
      }.to change(LearningAssignment, :count).by(1)
        .and change(Learning::NotificationLog, :count).by(1)

      log = Learning::NotificationLog.last
      expect(flash[:notice]).to include("配布：1件")
      expect(flash[:notice]).to include("未連携スキップ：1件")
      expect(log.notification_type).to eq("assignment_created")
      expect(log.status).to eq("skipped")
      expect(log.error_message).to eq("LINE recipient is not connected")
    end

    it "他顧問の生徒には配布しないこと" do
      other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
      other_student = create(:learning_student, customer: other_teacher)
      create_connected_line(other_student, "UotherAssignmentUser")
      adapter = successful_adapter

      expect {
        post learning_assignments_path, params: assignment_params(student_ids: [other_student.id])
      }.not_to change(LearningAssignment, :count)

      expect(response).to redirect_to(learning_students_path)
      expect(flash[:notice]).to include("配布：0件")
      expect(adapter).not_to have_received(:deliver)
    end

    it "title空では作成しないこと" do
      student = create(:learning_student, customer: teacher)
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post learning_assignments_path, params: assignment_params(student_ids: [student.id], title: " ")
      }.not_to change(LearningAssignment, :count)

      expect(response).to redirect_to(learning_students_path)
      expect(flash[:alert]).to include("タイトルを入力")
    end

    it "student_ids空では作成しないこと" do
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post learning_assignments_path, params: assignment_params(student_ids: [])
      }.not_to change(LearningAssignment, :count)

      expect(response).to redirect_to(learning_students_path)
      expect(flash[:alert]).to include("生徒を選択")
    end

    it "due_onを任意で保存できること" do
      student = create(:learning_student, customer: teacher)
      successful_adapter

      post learning_assignments_path, params: assignment_params(student_ids: [student.id], due_on: "")

      expect(response).to redirect_to(learning_students_path)
      expect(LearningAssignment.last.due_on).to be_nil
    end

    it "一部LINE通知に失敗しても他生徒の配布は続くこと" do
      failed_student = create(:learning_student, customer: teacher)
      sent_student = create(:learning_student, customer: teacher)
      create_connected_line(failed_student, "UfailedAssignmentUser")
      create_connected_line(sent_student, "UsentAssignmentUser")
      mixed_adapter(failed_student: failed_student)

      expect {
        post learning_assignments_path, params: assignment_params(student_ids: [failed_student.id, sent_student.id])
      }.to change(LearningAssignment, :count).by(2)
        .and change(Learning::NotificationLog, :count).by(2)

      expect(flash[:notice]).to include("配布：2件")
      expect(flash[:notice]).to include("LINE通知成功：1件")
      expect(flash[:notice]).to include("失敗：1件")
      expect(Learning::NotificationLog.find_by!(learning_student: failed_student).status).to eq("failed")
      expect(Learning::NotificationLog.find_by!(learning_student: sent_student).status).to eq("sent")
    end
  end

  def assignment_params(student_ids:, title: nil, description: nil, due_on: nil)
    {
      student_ids: student_ids,
      learning_assignment: {
        title: title.nil? ? __send__(:title) : title,
        description: description.nil? ? __send__(:description) : description,
        due_on: due_on.nil? ? __send__(:due_on) : due_on
      }
    }
  end

  def create_connected_line(student, line_user_id)
    create(:learning_line_connection,
           customer: student.customer,
           learning_student: student,
           line_user_id: line_user_id,
           status: "connected",
           connected_at: Time.current)
  end

  def successful_adapter
    adapter = instance_double(Learning::LineNotificationAdapter)
    allow(Learning::LineNotificationAdapter).to receive(:new).and_return(adapter)
    allow(adapter).to receive(:deliver) do |log|
      log.update!(status: "sent", sent_at: Time.current)
      Learning::LineNotificationAdapter::Result.new(status: :ok, message: "sent", payload: {})
    end
    adapter
  end

  def mixed_adapter(failed_student:)
    adapter = instance_double(Learning::LineNotificationAdapter)
    allow(Learning::LineNotificationAdapter).to receive(:new).and_return(adapter)
    allow(adapter).to receive(:deliver) do |log|
      if log.learning_student == failed_student
        log.update!(status: "failed", error_message: "LINE push message failed")
        Learning::LineNotificationAdapter::Result.new(status: :http_error, message: "LINE push message failed", payload: {})
      else
        log.update!(status: "sent", sent_at: Time.current)
        Learning::LineNotificationAdapter::Result.new(status: :ok, message: "sent", payload: {})
      end
    end
    adapter
  end
end
