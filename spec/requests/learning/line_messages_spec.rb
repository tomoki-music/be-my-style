require "rails_helper"

RSpec.describe "Learning line messages", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:student) { create(:learning_student, customer: teacher, nickname: "ギターさん") }
  let(:message) { "今日の練習、5分だけでもOKなのでやってみよう！" }

  before { sign_in teacher }

  describe "POST /learning/students/:student_id/line_message" do
    it "LINE連携済み生徒に個別メッセージを送信しteacher_messageログを保存すること" do
      create_connected_line(student)
      adapter = successful_adapter

      expect {
        post learning_student_line_message_path(student), params: { line_message: { message: message } }
      }.to change(Learning::NotificationLog, :count).by(1)

      log = Learning::NotificationLog.last
      expect(response).to redirect_to(learning_student_path(student))
      expect(flash[:notice]).to include("LINEメッセージを送信")
      expect(log.learning_student).to eq(student)
      expect(log.customer).to eq(teacher)
      expect(log.notification_type).to eq("teacher_message")
      expect(log.level).to eq("info")
      expect(log.delivery_channel).to eq("line")
      expect(log.status).to eq("sent")
      expect(log.message).to eq(message)
      expect(log.recommended_action).to eq("先生からのメッセージです。")
      expect(adapter).to have_received(:deliver).with(log)
    end

    it "LINE未連携生徒には送信せずskippedログを保存すること" do
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post learning_student_line_message_path(student), params: { line_message: { message: message } }
      }.to change(Learning::NotificationLog, :count).by(1)

      log = Learning::NotificationLog.last
      expect(response).to redirect_to(learning_student_path(student))
      expect(flash[:alert]).to include("LINE未連携")
      expect(log.notification_type).to eq("teacher_message")
      expect(log.status).to eq("skipped")
      expect(log.error_message).to eq("LINE recipient is not connected")
    end

    it "空文字は送信しないこと" do
      create_connected_line(student)
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post learning_student_line_message_path(student), params: { line_message: { message: "   " } }
      }.not_to change(Learning::NotificationLog, :count)

      expect(response).to redirect_to(learning_student_path(student))
      expect(flash[:alert]).to include("入力してください")
    end

    it "500文字を超えるメッセージは送信しないこと" do
      create_connected_line(student)
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        post learning_student_line_message_path(student), params: { line_message: { message: "あ" * 501 } }
      }.not_to change(Learning::NotificationLog, :count)

      expect(response).to redirect_to(learning_student_path(student))
      expect(flash[:alert]).to include("500文字以内")
    end

    it "他顧問の生徒には送れないこと" do
      other_teacher = create(:customer, domain_name: "learning", confirmed_at: Time.current)
      other_student = create(:learning_student, customer: other_teacher)
      create_connected_line(other_student)
      expect(Learning::LineNotificationAdapter).not_to receive(:new)

      expect {
        expect {
          post learning_student_line_message_path(other_student), params: { line_message: { message: message } }
        }.to raise_error(ActiveRecord::RecordNotFound)
      }.not_to change(Learning::NotificationLog, :count)
    end

    it "送信失敗時もfailedログを残して画面は落とさないこと" do
      create_connected_line(student)
      adapter = failed_adapter

      post learning_student_line_message_path(student), params: { line_message: { message: message } }

      log = Learning::NotificationLog.last
      expect(response).to redirect_to(learning_student_path(student))
      expect(flash[:alert]).to include("送信に失敗")
      expect(log.status).to eq("failed")
      expect(log.error_message).to eq("LINE push message failed")
      expect(adapter).to have_received(:deliver).with(log)
    end
  end

  def create_connected_line(target_student)
    create(:learning_line_connection,
           customer: target_student.customer,
           learning_student: target_student,
           line_user_id: "UteacherMessageLineUserId",
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

  def failed_adapter
    adapter = instance_double(Learning::LineNotificationAdapter)
    allow(Learning::LineNotificationAdapter).to receive(:new).and_return(adapter)
    allow(adapter).to receive(:deliver) do |log|
      log.update!(status: "failed", error_message: "LINE push message failed")
      Learning::LineNotificationAdapter::Result.new(status: :http_error, message: "LINE push message failed", payload: {})
    end
    adapter
  end
end
