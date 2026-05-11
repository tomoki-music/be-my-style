require "rails_helper"

RSpec.describe Learning::AutoReminderService do
  let(:customer) { create(:customer, domain_name: "learning") }
  let(:line_adapter) { instance_double(Learning::LineNotificationAdapter) }

  before do
    create(:learning_notification_setting, customer: customer, auto_reminder_enabled: true)
    allow(line_adapter).to receive(:deliver) do |log|
      log.update!(status: "sent", sent_at: Time.current, error_message: nil)
      Learning::LineNotificationAdapter::Result.new(status: :ok, message: "sent", payload: {})
    end
  end

  describe "#call" do
    it "auto_reminder_enabled=false では送信対象外になること" do
      customer.learning_notification_setting.update!(auto_reminder_enabled: false)
      connected_student

      expect {
        results = described_class.new(customer, line_adapter: line_adapter).call
        expect(results).to be_empty
      }.not_to change(Learning::NotificationLog, :count)
      expect(line_adapter).not_to have_received(:deliver)
    end

    it "auto_reminder_enabled=true で対象になること" do
      connected_student

      results = described_class.new(customer, line_adapter: line_adapter).call

      expect(results.map { |result| result.candidate.notification_type }).to include("auto_inactive_reminder")
    end

    it "send_hour外では送信対象外になること" do
      customer.learning_notification_setting.update!(auto_reminder_send_hour: 8)
      connected_student
      reference_time = Time.zone.local(2026, 5, 11, 18, 0, 0)

      results = described_class.new(customer, line_adapter: line_adapter, reference_time: reference_time).call

      expect(results).to be_empty
      expect(line_adapter).not_to have_received(:deliver)
    end

    it "3日以上未反応のLINE連携済み生徒が対象になること" do
      student = connected_student
      create(:learning_notification_log,
             customer: customer,
             learning_student: student,
             delivery_channel: "line",
             status: "sent",
             reaction_received: true,
             reacted_at: 4.days.ago,
             generated_at: 4.days.ago)

      results = described_class.new(customer, line_adapter: line_adapter).call

      expect(results.map { |result| result.candidate.notification_type }).to include("auto_inactive_reminder")
      log = Learning::NotificationLog.find_by!(learning_student: student, notification_type: "auto_inactive_reminder")
      expect(log.status).to eq("sent")
      expect(line_adapter).to have_received(:deliver).once
    end

    it "LINE未連携生徒は対象外になること" do
      create(:learning_student, customer: customer)

      expect {
        results = described_class.new(customer, line_adapter: line_adapter).call
        expect(results).to be_empty
      }.not_to change(Learning::NotificationLog, :count)
      expect(line_adapter).not_to have_received(:deliver)
    end

    it "24時間以内の同種送信はskippedになること" do
      student = connected_student
      create(:learning_notification_log,
             customer: customer,
             learning_student: student,
             notification_type: "auto_inactive_reminder",
             delivery_channel: "line",
             status: "sent",
             generated_at: 1.hour.ago,
             sent_at: 1.hour.ago)

      results = described_class.new(customer, line_adapter: line_adapter).call

      result = results.detect { |item| item.candidate.notification_type == "auto_inactive_reminder" }
      expect(result.status).to eq("skipped")
      expect(result.message).to eq("duplicate_recently_sent")
      expect(result.log.error_message).to eq("duplicate_recently_sent")
      expect(line_adapter).not_to have_received(:deliver)
    end

    it "DRY_RUNでは実送信しないこと" do
      connected_student

      expect {
        results = described_class.new(customer, dry_run: true, line_adapter: line_adapter).call
        expect(results.first.status).to eq("previewed")
      }.not_to change(Learning::NotificationLog, :count)
      expect(line_adapter).not_to have_received(:deliver)
    end

    it "期限前日課題が対象になること" do
      student = connected_student
      create(:learning_notification_log,
             customer: customer,
             learning_student: student,
             delivery_channel: "line",
             status: "sent",
             reaction_received: true,
             reacted_at: 1.hour.ago,
             generated_at: 1.hour.ago)
      assignment = create(:learning_assignment,
                          customer: customer,
                          learning_student: student,
                          due_on: Date.current.tomorrow,
                          status: "pending")

      results = described_class.new(customer, line_adapter: line_adapter).call

      result = results.detect { |item| item.candidate.assignment == assignment }
      expect(result.candidate.notification_type).to eq("auto_assignment_due_reminder")
      expect(result.candidate.message).to include("今週のトレーニング")
      expect(result.status).to eq("sent")
    end

    it "完了済み課題は対象外になること" do
      student = connected_student
      create(:learning_assignment,
             customer: customer,
             learning_student: student,
             due_on: Date.current.tomorrow,
             status: "completed")

      results = described_class.new(customer, line_adapter: line_adapter).call

      expect(results.map { |result| result.candidate.notification_type }).not_to include("auto_assignment_due_reminder")
    end

    it "先生確認待ち課題は未提出リマインド対象外になること" do
      student = connected_student
      create(:learning_assignment,
             customer: customer,
             learning_student: student,
             due_on: Date.current.tomorrow,
             status: "pending_review",
             submitted_at: Time.current)

      results = described_class.new(customer, line_adapter: line_adapter).call

      expect(results.map { |result| result.candidate.notification_type }).not_to include("auto_assignment_due_reminder")
    end

    it "期限超過課題が対象になること" do
      student = connected_student
      create(:learning_notification_log,
             customer: customer,
             learning_student: student,
             delivery_channel: "line",
             status: "sent",
             reaction_received: true,
             reacted_at: 1.hour.ago,
             generated_at: 1.hour.ago)
      assignment = create(:learning_assignment,
                          customer: customer,
                          learning_student: student,
                          due_on: Date.current.yesterday,
                          status: "in_progress")

      results = described_class.new(customer, line_adapter: line_adapter).call

      result = results.detect { |item| item.candidate.assignment == assignment }
      expect(result.candidate.notification_type).to eq("auto_assignment_overdue_reminder")
      expect(result.status).to eq("sent")
    end

    it "自動送信は1生徒あたり1日最大1通に制御すること" do
      student = connected_student
      create(:learning_assignment,
             customer: customer,
             learning_student: student,
             due_on: Date.current.yesterday,
             status: "pending")

      results = described_class.new(customer, line_adapter: line_adapter).call

      expect(results.map(&:status)).to include("sent", "skipped")
      expect(results.find { |result| result.message == "auto_daily_limit" }).to be_present
      expect(line_adapter).to have_received(:deliver).once
    end
  end

  describe "#summary" do
    it "種類別の候補数を返すこと" do
      inactive_student = connected_student
      due_student = connected_student
      overdue_student = connected_student
      create_recent_reaction(inactive_student)
      create_recent_reaction(due_student)
      create_recent_reaction(overdue_student)
      create(:learning_assignment, customer: customer, learning_student: due_student, due_on: Date.current.tomorrow)
      create(:learning_assignment, customer: customer, learning_student: overdue_student, due_on: Date.current.yesterday)

      summary = described_class.new(customer, dry_run: true).summary

      expect(summary.inactive_count).to eq(0)
      expect(summary.due_tomorrow_count).to eq(1)
      expect(summary.overdue_count).to eq(1)
    end
  end

  def connected_student
    student = create(:learning_student, customer: customer)
    create(:learning_line_connection,
           customer: customer,
           learning_student: student,
           status: "connected",
           connected_at: Time.current)
    student
  end

  def create_recent_reaction(student)
    create(:learning_notification_log,
           customer: customer,
           learning_student: student,
           delivery_channel: "line",
           status: "sent",
           reaction_received: true,
           reacted_at: 1.hour.ago,
           generated_at: 1.hour.ago)
  end
end
