require "rails_helper"

RSpec.describe "Learning followup line messages", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:message) { Learning::FollowupLineMessagesController::DEFAULT_MESSAGE }

  before { sign_in teacher }

  describe "POST /learning/followup_line_messages" do
    it "要フォローかつLINE連携済み生徒にfollowup_messageを送信すること" do
      student = create_at_risk_student(name: "山田太郎")
      create_connected_line(student, "UfollowupLineUser")
      adapter = successful_adapter

      expect {
        post learning_followup_line_messages_path,
             params: { student_ids: [student.id], followup_line_message: { message: message } }
      }.to change(Learning::NotificationLog, :count).by(1)

      log = Learning::NotificationLog.last
      expect(response).to redirect_to(learning_teacher_dashboard_path)
      expect(flash[:notice]).to include("成功：1件")
      expect(log.learning_student).to eq(student)
      expect(log.notification_type).to eq("followup_message")
      expect(log.delivery_channel).to eq("line")
      expect(log.status).to eq("sent")
      expect(log.message).to eq(message)
      expect(adapter).to have_received(:deliver).once
    end

    it "未連携の要フォロー生徒はskippedログを保存すること" do
      student = create_at_risk_student(name: "佐藤花子")
      successful_adapter

      expect {
        post learning_followup_line_messages_path,
             params: { student_ids: [student.id], followup_line_message: { message: message } }
      }.to change(Learning::NotificationLog, :count).by(1)

      log = Learning::NotificationLog.last
      expect(flash[:notice]).to include("未連携：1件")
      expect(log.notification_type).to eq("followup_message")
      expect(log.status).to eq("skipped")
      expect(log.error_message).to eq("LINE recipient is not connected")
    end

    it "他顧問の生徒には送信されないこと" do
      other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
      other_student = create(:learning_student, customer: other_teacher)
      create(:learning_assignment, customer: other_teacher, learning_student: other_student,
                                   status: "pending", created_at: Time.current)
      create_connected_line(other_student, "UotherTeacherFollowupUser")
      adapter = successful_adapter

      expect {
        post learning_followup_line_messages_path,
             params: { student_ids: [other_student.id], followup_line_message: { message: message } }
      }.not_to change(Learning::NotificationLog, :count)

      expect(flash[:notice]).to include("成功：0件")
      expect(adapter).not_to have_received(:deliver)
    end

    it "要フォローではない生徒には送信されないこと" do
      student = create(:learning_student, customer: teacher)
      create(:learning_assignment, customer: teacher, learning_student: student,
                                   status: "completed", completed_at: Time.current)
      create(:learning_notification_log, customer: teacher, learning_student: student,
                                         delivery_channel: "line", status: "sent",
                                         generated_at: Time.current,
                                         reaction_received: true,
                                         reacted_at: Time.current)
      create_connected_line(student, "UhealthyFollowupUser")
      adapter = successful_adapter

      expect {
        post learning_followup_line_messages_path,
             params: { student_ids: [student.id], followup_line_message: { message: message } }
      }.not_to change(Learning::NotificationLog, :count)

      expect(flash[:notice]).to include("成功：0件")
      expect(adapter).not_to have_received(:deliver)
    end

    it "空メッセージと500文字超過を拒否すること" do
      student = create_at_risk_student
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post learning_followup_line_messages_path,
             params: { student_ids: [student.id], followup_line_message: { message: "   " } }
      }.not_to change(Learning::NotificationLog, :count)
      expect(flash[:alert]).to include("入力してください")

      expect {
        post learning_followup_line_messages_path,
             params: { student_ids: [student.id], followup_line_message: { message: "あ" * 501 } }
      }.not_to change(Learning::NotificationLog, :count)
      expect(flash[:alert]).to include("500文字以内")
    end

    it "一部失敗しても送信を継続し件数を表示すること" do
      failed_student = create_at_risk_student(name: "失敗生徒")
      sent_student = create_at_risk_student(name: "成功生徒")
      skipped_student = create_at_risk_student(name: "未連携生徒")
      create_connected_line(failed_student, "UfailedFollowupUser")
      create_connected_line(sent_student, "UsentFollowupUser")
      mixed_adapter(failed_student: failed_student)

      expect {
        post learning_followup_line_messages_path,
             params: { student_ids: [failed_student.id, sent_student.id, skipped_student.id], followup_line_message: { message: message } }
      }.to change(Learning::NotificationLog, :count).by(3)

      expect(flash[:notice]).to include("成功：1件")
      expect(flash[:notice]).to include("未連携：1件")
      expect(flash[:notice]).to include("失敗：1件")
      expect(Learning::NotificationLog.find_by!(learning_student: failed_student).status).to eq("failed")
      expect(Learning::NotificationLog.find_by!(learning_student: sent_student).status).to eq("sent")
      expect(Learning::NotificationLog.find_by!(learning_student: skipped_student).status).to eq("skipped")
    end
  end

  def create_at_risk_student(name: "要フォロー生徒")
    student = create(:learning_student, customer: teacher, name: name)
    create(:learning_assignment, customer: teacher, learning_student: student,
                                 status: "pending", created_at: Time.current)
    student
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
