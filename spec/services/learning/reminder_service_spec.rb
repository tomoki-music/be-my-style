require "rails_helper"

RSpec.describe Learning::ReminderService do
  let(:customer) { create(:customer, domain_name: "learning") }

  describe ".for_customer" do
    it "生徒リマインド通知OFFなら定期実行候補を返さないこと" do
      create(:learning_notification_setting, customer: customer, reminder_enabled: false)
      student = create(:learning_student, customer: customer)
      create(:learning_progress_log, customer: customer, learning_student: student,
                                    practiced_on: 5.days.ago.to_date)

      expect(described_class.for_customer(customer)).to eq([])
    end
  end
end
