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
  end

  describe "#dispatch" do
    it "将来チャネル向けの planned delivery を返すこと" do
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)

      deliveries = described_class.new(customer, channels: %i[line email unknown]).dispatch

      expect(deliveries.map(&:channel)).to eq(%i[line email])
      expect(deliveries.map(&:status)).to eq(%i[planned planned])
      expect(deliveries.first.reminder.student).to eq(student)
    end
  end
end
