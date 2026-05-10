require "rails_helper"

RSpec.describe "Learning assignment show", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  describe "GET /learning/assignments/:id" do
    it "課題情報・提出率・生徒状態を表示すること" do
      group_key = "phase23-show-group"
      completed = create_assignment(group_key: group_key, status: "completed", completed_at: 1.hour.ago)
      pending = create_assignment(group_key: group_key, status: "pending")

      get learning_assignment_path(completed)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ライブ前基礎練習")
      expect(response.body).to include("50%")
      expect(response.body).to include(completed.learning_student.display_name)
      expect(response.body).to include(pending.learning_student.display_name)
      expect(response.body).to include("完了")
      expect(response.body).to include("未着手")
    end

    it "未提出フィルタでpending/in_progressだけ表示すること" do
      group_key = "phase23-unsubmitted-filter"
      completed = create_assignment(group_key: group_key, status: "completed")
      pending = create_assignment(group_key: group_key, status: "pending")

      get learning_assignment_path(completed, status: "unsubmitted")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(pending.learning_student.display_name)
      expect(response.body).not_to include(completed.learning_student.display_name)
    end

    it "LINE未連携フィルタで未連携生徒だけ表示すること" do
      group_key = "phase23-line-filter"
      connected = create_assignment(group_key: group_key, status: "pending")
      unconnected = create_assignment(group_key: group_key, status: "pending")
      create_connected_line(connected.learning_student, "Uphase23Connected")

      get learning_assignment_path(connected, line: "unconnected")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(unconnected.learning_student.display_name)
      expect(response.body).not_to include(connected.learning_student.display_name)
    end

    it "3日以上未反応フィルタで最近反応した生徒を除外すること" do
      group_key = "phase23-inactive-filter"
      inactive = create_assignment(group_key: group_key, status: "pending")
      active = create_assignment(group_key: group_key, status: "pending")
      create(:learning_notification_log,
             customer: teacher,
             learning_student: active.learning_student,
             reaction_received: true,
             reacted_at: 1.day.ago)

      get learning_assignment_path(inactive, inactive: "1")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(inactive.learning_student.display_name)
      expect(response.body).not_to include(active.learning_student.display_name)
    end

    it "期限超過を表示すること" do
      assignment = create_assignment(status: "pending", due_on: Date.current - 1.day)

      get learning_assignment_path(assignment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("期限超過")
    end

    it "他顧問のassignmentは閲覧できないこと" do
      other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
      assignment = create(:learning_assignment, customer: other_teacher)

      expect {
        get learning_assignment_path(assignment)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "POST /learning/assignments/:id/bulk_reminder" do
    it "未提出者だけにLINEを送信しcompletedには送らないこと" do
      group_key = "phase23-reminder"
      pending = create_assignment(group_key: group_key, status: "pending")
      in_progress = create_assignment(group_key: group_key, status: "in_progress")
      completed = create_assignment(group_key: group_key, status: "completed")
      [pending, in_progress, completed].each_with_index do |assignment, index|
        create_connected_line(assignment.learning_student, "Uphase23Reminder#{index}")
      end
      adapter = successful_adapter

      expect {
        post bulk_reminder_learning_assignment_path(pending),
             params: { assignment_reminder: { message: "提出を待っています。終わったら「やった！」と返信してね" } }
      }.to change(Learning::NotificationLog, :count).by(2)

      expect(response).to redirect_to(learning_assignment_path(pending))
      expect(flash[:notice]).to include("送信成功：2件")
      expect(adapter).to have_received(:deliver).twice
      expect(Learning::NotificationLog.where(learning_student: completed.learning_student)).to be_empty
    end

    it "未連携の未提出者はskippedにすること" do
      assignment = create_assignment(status: "pending")
      successful_adapter

      expect {
        post bulk_reminder_learning_assignment_path(assignment)
      }.to change(Learning::NotificationLog, :count).by(1)

      log = Learning::NotificationLog.last
      expect(response).to redirect_to(learning_assignment_path(assignment))
      expect(flash[:notice]).to include("未連携スキップ：1件")
      expect(log.status).to eq("skipped")
    end

    it "他顧問のassignment_idでは送信できないこと" do
      other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
      assignment = create(:learning_assignment, customer: other_teacher)
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post bulk_reminder_learning_assignment_path(assignment)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  def create_assignment(group_key: "phase23-default-group", status: "pending", due_on: Date.current + 7.days, completed_at: nil)
    create(:learning_assignment,
           customer: teacher,
           title: "ライブ前基礎練習",
           status: status,
           due_on: due_on,
           completed_at: completed_at,
           assignment_group_key: group_key)
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
end
