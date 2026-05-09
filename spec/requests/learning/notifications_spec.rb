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
      expect(response.body).to include("ギターさん")
      expect(response.body).to include("5日")
      expect(response.body).to include("もう一度始めてみよう")
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
end
