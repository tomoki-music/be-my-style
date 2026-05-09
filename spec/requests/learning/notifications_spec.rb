require "rails_helper"

RSpec.describe "Learning notifications", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  describe "GET /learning/notifications" do
    it "現在の通知方式と通知候補を表示すること" do
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")
      create(:learning_progress_log, customer: teacher, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)

      get learning_notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("現在の通知方式：手動コピー")
      expect(response.body).to include("今日の通知候補を履歴に保存")
      expect(response.body).to include("LINEリマインド運用中")
      expect(response.body).to include("未連携やENV未設定の場合はskippedとして記録")
      expect(response.body).to include("ギターさん")
      expect(response.body).to include("5日")
      expect(response.body).to include("もう一度始めてみよう")
    end

    it "保存済み通知履歴を表示すること" do
      student = create(:learning_student, customer: teacher, nickname: "ベースさん")
      create(:learning_notification_log,
             customer: teacher,
             learning_student: student,
             notification_type: "reminder",
             level: "strong",
             status: "previewed",
             message: "もう一度始めてみよう",
             recommended_action: "先生から声かけして再スタートする")

      get learning_notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("保存済み通知履歴")
      expect(response.body).to include("ベースさん")
      expect(response.body).to include("previewed")
      expect(response.body).to include("先生から声かけして再スタートする")
    end

    it "生徒リマインド通知OFFなら通知候補を表示しないこと" do
      create(:learning_notification_setting, customer: teacher, reminder_enabled: false)
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")
      create(:learning_progress_log, customer: teacher, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)

      get learning_notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("生徒リマインド通知はOFFです")
      expect(response.body).not_to include("ギターさん")
    end
  end

  describe "POST /learning/notifications/persist_preview" do
    it "今日の通知候補を履歴に保存すること" do
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")
      create(:learning_progress_log, customer: teacher, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)

      expect {
        post persist_preview_learning_notifications_path
      }.to change(Learning::NotificationLog, :count).by(1)

      expect(response).to redirect_to(learning_notifications_path)
      expect(Learning::NotificationLog.last.learning_student).to eq(student)
    end

    it "生徒リマインド通知OFFなら履歴保存しないこと" do
      create(:learning_notification_setting, customer: teacher, reminder_enabled: false)
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")
      create(:learning_progress_log, customer: teacher, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)

      expect {
        post persist_preview_learning_notifications_path
      }.not_to change(Learning::NotificationLog, :count)

      expect(response).to redirect_to(learning_notifications_path)
    end
  end
end
