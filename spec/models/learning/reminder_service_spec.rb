require "rails_helper"

RSpec.describe Learning::ReminderService do
  let(:customer) { create(:customer, domain_name: "learning") }
  let(:student) { create(:learning_student, customer: customer) }

  describe ".for_student" do
    it "2日未実施は軽いリマインドを返すこと" do
      reminder = described_class.for_student(student, last_practiced_on: 2.days.ago.to_date)

      expect(reminder).to be_active
      expect(reminder.stage).to eq(2)
      expect(reminder.tone).to eq("light")
      expect(reminder.level).to eq("light")
      expect(reminder.message).to eq("少し間が空いています！1つだけやってみよう")
      expect(reminder.recommended_action).to eq("今日やることを1つだけ開く")
      expect(reminder.notification_type).to eq("2日")
      expect(reminder.generated_at).to be_present
    end

    it "3日未実施は少し強めのリマインドを返すこと" do
      reminder = described_class.for_student(student, last_practiced_on: 3.days.ago.to_date)

      expect(reminder.stage).to eq(3)
      expect(reminder.level).to eq("normal")
      expect(reminder.message).to eq("ここで戻ると差がつきます")
      expect(reminder.recommended_action).to eq("短い練習を選んで再開する")
    end

    it "5日以上未実施は強めのリマインドを返すこと" do
      reminder = described_class.for_student(student, last_practiced_on: 8.days.ago.to_date)

      expect(reminder.stage).to eq(5)
      expect(reminder.level).to eq("strong")
      expect(reminder.message).to eq("もう一度始めてみよう")
      expect(reminder.recommended_action).to eq("先生から声かけして再スタートする")
    end

    it "1日以内または記録なしは対象外にすること" do
      expect(described_class.for_student(student, last_practiced_on: Date.current)).not_to be_active
      expect(described_class.for_student(student, last_practiced_on: nil)).not_to be_active
    end
  end

  describe ".for_customer" do
    it "対象生徒だけを返すこと" do
      active_student = create(:learning_student, customer: customer)
      recent_student = create(:learning_student, customer: customer)
      create(:learning_progress_log, customer: customer, learning_student: active_student,
                                    practiced_on: 3.days.ago.to_date)
      create(:learning_progress_log, customer: customer, learning_student: recent_student,
                                    practiced_on: Date.current)

      reminders = described_class.for_customer(customer)

      expect(reminders.map(&:student)).to eq([active_student])
    end

    it "設定がない場合はデフォルトONとして通知候補を返すこと" do
      active_student = create(:learning_student, customer: customer)
      create(:learning_progress_log, customer: customer, learning_student: active_student,
                                    practiced_on: 3.days.ago.to_date)

      expect(described_class.for_customer(customer).map(&:student)).to eq([active_student])
    end

    it "生徒リマインド通知OFFなら通知候補を返さないこと" do
      create(:learning_notification_setting, customer: customer, reminder_enabled: false)
      active_student = create(:learning_student, customer: customer)
      create(:learning_progress_log, customer: customer, learning_student: active_student,
                                    practiced_on: 3.days.ago.to_date)

      expect(described_class.for_customer(customer)).to eq([])
    end
  end
end
