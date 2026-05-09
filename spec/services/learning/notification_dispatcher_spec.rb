require "rails_helper"

RSpec.describe Learning::NotificationDispatcher do
  let(:customer) { create(:customer, domain_name: "learning") }
  let(:student) { create(:learning_student, customer: customer) }

  describe "#preview" do
    it "ReminderService の通知候補を保存せずに返すこと" do
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 3.days.ago.to_date)

      notifications = described_class.new(customer).preview

      expect(notifications.size).to eq(1)
      expect(notifications.first.student).to eq(student)
      expect(notifications.first.level).to eq("normal")
    end

    it "生徒リマインド通知OFFなら通知候補を返さないこと" do
      create(:learning_notification_setting, customer: customer, reminder_enabled: false)
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 3.days.ago.to_date)

      expect(described_class.new(customer).preview).to eq([])
    end
  end

  describe "#persist_preview!" do
    it "通知候補を通知履歴として保存すること" do
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 3.days.ago.to_date)

      expect {
        described_class.new(customer).persist_preview!
      }.to change(Learning::NotificationLog, :count).by(1)

      log = Learning::NotificationLog.last
      expect(log.customer).to eq(customer)
      expect(log.learning_student).to eq(student)
      expect(log.notification_type).to eq("reminder")
      expect(log.level).to eq("normal")
      expect(log.status).to eq("previewed")
      expect(log.delivery_channel).to eq("manual")
      expect(log.message).to eq("ここで戻ると差がつきます")
      expect(log.metadata["stage"]).to eq(3)
    end

    it "同日同種同生徒の通知履歴は重複保存しないこと" do
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 3.days.ago.to_date)

      dispatcher = described_class.new(customer)

      expect {
        dispatcher.persist_preview!
        dispatcher.persist_preview!
      }.to change(Learning::NotificationLog, :count).by(1)
    end

    it "生徒リマインド通知OFFなら保存しないこと" do
      create(:learning_notification_setting, customer: customer, reminder_enabled: false)
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 3.days.ago.to_date)

      expect {
        described_class.new(customer).persist_preview!
      }.not_to change(Learning::NotificationLog, :count)
    end
  end

  describe "#dispatch" do
    it "実送信せず、手動コピー設定では保存済み履歴を skipped にすること" do
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)

      logs = described_class.new(customer).dispatch

      expect(logs.size).to eq(1)
      expect(logs.first.status).to eq("skipped")
    end

    it "LINE未連携ならadapter no-opで skipped にすること" do
      create(:learning_notification_setting, customer: customer, delivery_channel: "line")
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)

      logs = described_class.new(customer).dispatch

      expect(logs.size).to eq(1)
      expect(logs.first.reload.status).to eq("skipped")
      expect(logs.first.delivery_channel).to eq("line")
    end

    it "LINE設定ではadapterを呼ぶがsentにはしないこと" do
      create(:learning_notification_setting, customer: customer, delivery_channel: "line")
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)
      line_adapter = instance_double(Learning::LineNotificationAdapter)
      allow(line_adapter).to receive(:deliver)

      logs = described_class.new(customer, line_adapter: line_adapter).dispatch

      expect(line_adapter).to have_received(:deliver).with(logs.first)
      expect(logs.first.reload.status).to eq("queued")
      expect(logs.first.sent_at).to be_nil
    end

    it "同日同種同生徒で送信済みの通知は再送しないこと" do
      create(:learning_notification_setting, customer: customer, delivery_channel: "line")
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)
      sent_log = create(:learning_notification_log,
                        customer: customer,
                        learning_student: student,
                        notification_type: "reminder",
                        delivery_channel: "line",
                        status: "sent",
                        sent_at: 1.hour.ago,
                        generated_at: Time.current)
      line_adapter = instance_double(Learning::LineNotificationAdapter)
      allow(line_adapter).to receive(:deliver)

      logs = described_class.new(customer, channels: [:line], line_adapter: line_adapter).dispatch

      expect(logs).to eq([sent_log])
      expect(line_adapter).not_to have_received(:deliver)
      expect(sent_log.reload.status).to eq("sent")
    end
  end
end
