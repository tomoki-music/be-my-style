require "rails_helper"

RSpec.describe "Learning bulk line messages", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:message) { "ライブまであと1週間！今日も5分だけ練習してみよう" }

  before { sign_in teacher }

  describe "POST /learning/students/bulk_line_message" do
    it "LINE連携済み複数生徒に送信しteacher_bulk_messageログを人数分保存すること" do
      students = create_list(:learning_student, 2, customer: teacher)
      students.each_with_index { |student, index| create_connected_line(student, "UbulkLineUser#{index}") }
      adapter = successful_adapter

      expect {
        post bulk_line_message_learning_students_path, params: { student_ids: students.map(&:id), bulk_line_message: { message: message } }
      }.to change(Learning::NotificationLog, :count).by(2)

      logs = Learning::NotificationLog.order(:created_at).last(2)
      expect(response).to redirect_to(learning_students_path)
      expect(flash[:notice]).to include("送信成功：2件")
      expect(flash[:notice]).to include("未連携スキップ：0件")
      expect(logs.map(&:learning_student)).to match_array(students)
      expect(logs.map(&:notification_type)).to all(eq("teacher_bulk_message"))
      expect(logs.map(&:status)).to all(eq("sent"))
      expect(logs.map(&:message)).to all(eq(message))
      expect(logs.map(&:recommended_action)).to all(eq("先生からの一括メッセージです。"))
      expect(adapter).to have_received(:deliver).twice
    end

    it "未連携生徒はskippedログを保存すること" do
      connected_student = create(:learning_student, customer: teacher)
      unconnected_student = create(:learning_student, customer: teacher)
      create_connected_line(connected_student, "UconnectedBulkUser")
      successful_adapter

      expect {
        post bulk_line_message_learning_students_path,
             params: { student_ids: [connected_student.id, unconnected_student.id], bulk_line_message: { message: message } }
      }.to change(Learning::NotificationLog, :count).by(2)

      skipped_log = Learning::NotificationLog.find_by!(learning_student: unconnected_student)
      expect(response).to redirect_to(learning_students_path)
      expect(flash[:notice]).to include("送信成功：1件")
      expect(flash[:notice]).to include("未連携スキップ：1件")
      expect(skipped_log.notification_type).to eq("teacher_bulk_message")
      expect(skipped_log.status).to eq("skipped")
      expect(skipped_log.error_message).to eq("LINE recipient is not connected")
    end

    it "空文字は送信しないこと" do
      student = create(:learning_student, customer: teacher)
      create_connected_line(student, "UblankBulkUser")
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post bulk_line_message_learning_students_path, params: { student_ids: [student.id], bulk_line_message: { message: "   " } }
      }.not_to change(Learning::NotificationLog, :count)

      expect(response).to redirect_to(learning_students_path)
      expect(flash[:alert]).to include("入力してください")
    end

    it "500文字を超えるメッセージは送信しないこと" do
      student = create(:learning_student, customer: teacher)
      create_connected_line(student, "UtooLongBulkUser")
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post bulk_line_message_learning_students_path, params: { student_ids: [student.id], bulk_line_message: { message: "あ" * 501 } }
      }.not_to change(Learning::NotificationLog, :count)

      expect(response).to redirect_to(learning_students_path)
      expect(flash[:alert]).to include("500文字以内")
    end

    it "student_ids空は送信しないこと" do
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post bulk_line_message_learning_students_path, params: { student_ids: [], bulk_line_message: { message: message } }
      }.not_to change(Learning::NotificationLog, :count)

      expect(response).to redirect_to(learning_students_path)
      expect(flash[:alert]).to include("選択してください")
    end

    it "他顧問の生徒には送信されないこと" do
      other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
      other_student = create(:learning_student, customer: other_teacher)
      create_connected_line(other_student, "UotherTeacherBulkUser")
      adapter = successful_adapter

      expect {
        post bulk_line_message_learning_students_path, params: { student_ids: [other_student.id], bulk_line_message: { message: message } }
      }.not_to change(Learning::NotificationLog, :count)

      expect(response).to redirect_to(learning_students_path)
      expect(flash[:notice]).to include("送信成功：0件")
      expect(adapter).not_to have_received(:deliver)
    end

    it "一部失敗しても他生徒の送信は続くこと" do
      failed_student = create(:learning_student, customer: teacher)
      sent_student = create(:learning_student, customer: teacher)
      create_connected_line(failed_student, "UfailedBulkUser")
      create_connected_line(sent_student, "UsentBulkUser")
      mixed_adapter(failed_student: failed_student)

      expect {
        post bulk_line_message_learning_students_path,
             params: { student_ids: [failed_student.id, sent_student.id], bulk_line_message: { message: message } }
      }.to change(Learning::NotificationLog, :count).by(2)

      expect(response).to redirect_to(learning_students_path)
      expect(flash[:notice]).to include("送信成功：1件")
      expect(flash[:notice]).to include("失敗：1件")
      expect(Learning::NotificationLog.find_by!(learning_student: failed_student).status).to eq("failed")
      expect(Learning::NotificationLog.find_by!(learning_student: sent_student).status).to eq("sent")
    end
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
