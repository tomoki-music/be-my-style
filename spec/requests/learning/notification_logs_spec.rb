require "rails_helper"

RSpec.describe "Learning notification logs", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  describe "GET /learning/notifications" do
    it "LINE通知のsent/skipped/failedを見分けて表示すること" do
      student = create(:learning_student, customer: teacher, nickname: "ギターさん")
      %w[sent skipped failed].each do |status|
        create(:learning_notification_log,
               customer: teacher,
               learning_student: student,
               delivery_channel: "line",
               status: status,
               message: "LINE #{status}",
               generated_at: Time.current)
      end

      get learning_notifications_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("learning-notification-status--sent")
      expect(response.body).to include("learning-notification-status--skipped")
      expect(response.body).to include("learning-notification-status--failed")
    end
  end
end
