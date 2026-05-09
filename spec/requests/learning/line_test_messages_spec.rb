require "rails_helper"

RSpec.describe "Learning line test messages", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:student) { create(:learning_student, customer: teacher, nickname: "ギターさん") }

  before { sign_in teacher }

  describe "POST /learning/students/:student_id/line_test_message" do
    it "テスト通知ログを作成してLINE送信成功を表示すること" do
      adapter = instance_double(Learning::LineNotificationAdapter)
      allow(Learning::LineNotificationAdapter).to receive(:new).and_return(adapter)
      allow(adapter).to receive(:deliver) do |log|
        log.update!(status: "sent", sent_at: Time.current)
        Learning::LineNotificationAdapter::Result.new(status: :ok, message: "sent", payload: {})
      end

      expect {
        post learning_student_line_test_message_path(student)
      }.to change(Learning::NotificationLog, :count).by(1)

      log = Learning::NotificationLog.last
      expect(response).to redirect_to(learning_student_path(student))
      expect(flash[:notice]).to include("LINEテスト送信に成功")
      expect(log.learning_student).to eq(student)
      expect(log.delivery_channel).to eq("line")
      expect(log.notification_type).to eq("teacher_action")
      expect(log.status).to eq("sent")
      expect(adapter).to have_received(:deliver).with(log)
    end

    it "送信失敗時は画面に失敗メッセージを表示すること" do
      adapter = instance_double(Learning::LineNotificationAdapter)
      allow(Learning::LineNotificationAdapter).to receive(:new).and_return(adapter)
      allow(adapter).to receive(:deliver) do |log|
        log.update!(status: "failed", error_message: "LINE push message failed")
        Learning::LineNotificationAdapter::Result.new(status: :http_error, message: "LINE push message failed", payload: {})
      end

      post learning_student_line_test_message_path(student)

      expect(response).to redirect_to(learning_student_path(student))
      expect(flash[:alert]).to include("LINEテスト送信に失敗")
      expect(Learning::NotificationLog.last.status).to eq("failed")
    end
  end
end
