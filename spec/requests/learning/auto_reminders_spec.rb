require "rails_helper"

RSpec.describe "Learning auto reminders", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }

  before { sign_in teacher }

  describe "GET /learning/auto_reminders" do
    it "preview画面に対象生徒・理由・文面が表示されること" do
      create(:learning_notification_setting, customer: teacher, auto_reminder_enabled: true)
      student = connected_student(name: "自動太郎")

      get learning_auto_reminders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("自動リマインド運用")
      expect(response.body).to include("ON")
      expect(response.body).to include("自動太郎")
      expect(response.body).to include("3日以上未反応")
      expect(response.body).to include("少し間が空いています")
      expect(response.body).to include("auto_inactive_reminder")
      expect(response.body).to include("LINE未連携")
      expect(student.line_connected?).to eq(true)
    end

    it "auto系ログが表示されること" do
      create(:learning_notification_setting, customer: teacher, auto_reminder_enabled: false)
      student = create(:learning_student, customer: teacher, name: "ログ花子")
      create(:learning_notification_log,
             customer: teacher,
             learning_student: student,
             notification_type: "auto_assignment_overdue_reminder",
             delivery_channel: "line",
             status: "skipped",
             title: "期限超過課題",
             message: "期限を過ぎた課題があります。まずは1つだけ開こう。",
             error_message: "duplicate_recently_sent",
             generated_at: Time.current)

      get learning_auto_reminders_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("自動送信ログ")
      expect(response.body).to include("ログ花子")
      expect(response.body).to include("auto_assignment_overdue_reminder")
      expect(response.body).to include("skipped")
      expect(response.body).to include("duplicate_recently_sent")
      expect(response.body).to include("期限を過ぎた課題")
    end

    it "duplicateと1日1通制御のskipped理由が表示されること" do
      create(:learning_notification_setting, customer: teacher, auto_reminder_enabled: true)
      duplicate_student = connected_student(name: "重複生徒")
      daily_limit_student = connected_student(name: "一通生徒")
      create(:learning_notification_log,
             customer: teacher,
             learning_student: duplicate_student,
             notification_type: "auto_inactive_reminder",
             delivery_channel: "line",
             status: "sent",
             generated_at: 1.hour.ago,
             sent_at: 1.hour.ago)
      create(:learning_assignment,
             customer: teacher,
             learning_student: daily_limit_student,
             due_on: Date.current.yesterday,
             status: "pending")

      get learning_auto_reminders_path

      expect(response.body).to include("重複生徒")
      expect(response.body).to include("duplicate_recently_sent")
      expect(response.body).to include("一通生徒")
      expect(response.body).to include("auto_daily_limit")
    end
  end

  describe "PATCH /learning/notification_settings" do
    it "自動送信ON/OFFと送信時間帯を保存すること" do
      patch learning_notification_settings_path, params: {
        learning_notification_setting: {
          auto_reminder_enabled: "1",
          auto_reminder_send_hour: "18",
          reminder_enabled: "1",
          teacher_summary_enabled: "1",
          student_reactivation_enabled: "1"
        }
      }

      expect(response).to redirect_to(edit_learning_notification_settings_path)
      setting = teacher.reload.learning_notification_setting
      expect(setting.auto_reminder_enabled).to eq(true)
      expect(setting.auto_reminder_send_hour).to eq(18)
    end
  end

  describe "POST /learning/followup_line_messages" do
    it "auto_reminder_enabled=false でも手動フォローLINE送信には影響しないこと" do
      create(:learning_notification_setting, customer: teacher, auto_reminder_enabled: false)
      student = create_at_risk_student(name: "手動生徒")
      create_connected_line(student, "UmanualFollowupUser")
      adapter = successful_adapter

      expect {
        post learning_followup_line_messages_path,
             params: {
               student_ids: [student.id],
               followup_line_message: { message: Learning::FollowupLineMessagesController::DEFAULT_MESSAGE }
             }
      }.to change(Learning::NotificationLog, :count).by(1)

      expect(Learning::NotificationLog.last.notification_type).to eq("followup_message")
      expect(Learning::NotificationLog.last.status).to eq("sent")
      expect(adapter).to have_received(:deliver).once
    end
  end

  def connected_student(name:)
    student = create(:learning_student, customer: teacher, name: name)
    create_connected_line(student, "U#{student.id.to_s.rjust(32, '0')}")
    student
  end

  def create_at_risk_student(name:)
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
end
