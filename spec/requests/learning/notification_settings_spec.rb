require "rails_helper"

RSpec.describe "Learning notification settings", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  describe "GET /learning/notification_settings/edit" do
    it "デフォルト設定を表示すること" do
      get edit_learning_notification_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("通知設定")
      expect(response.body).to include("生徒リマインド通知")
      expect(response.body).to include("顧問向け週次まとめ")
      expect(response.body).to include("生徒復帰通知")
      expect(response.body).to include("手動コピー")
      expect(response.body).to include("メール：準備中")
      expect(response.body).to include("LINE：準備中")
      expect(response.body).to include('disabled="disabled"')
    end
  end

  describe "PATCH /learning/notification_settings" do
    it "通知ON/OFFを保存し、配信方法は手動コピーに固定すること" do
      patch learning_notification_settings_path, params: {
        learning_notification_setting: {
          reminder_enabled: "0",
          teacher_summary_enabled: "1",
          student_reactivation_enabled: "0",
          delivery_channel: "line"
        }
      }

      expect(response).to redirect_to(edit_learning_notification_settings_path)
      setting = teacher.reload.learning_notification_setting
      expect(setting.reminder_enabled).to eq(false)
      expect(setting.teacher_summary_enabled).to eq(true)
      expect(setting.student_reactivation_enabled).to eq(false)
      expect(setting.delivery_channel).to eq("manual")
    end
  end
end
