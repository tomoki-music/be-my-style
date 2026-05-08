require "rails_helper"

RSpec.describe Learning::NotificationSetting do
  let(:customer) { create(:customer, domain_name: "learning") }

  describe ".effective_for" do
    it "設定がない場合は保存せずにデフォルトON/manualを返すこと" do
      setting = described_class.effective_for(customer)

      expect(setting).not_to be_persisted
      expect(setting.reminder_enabled).to eq(true)
      expect(setting.teacher_summary_enabled).to eq(true)
      expect(setting.student_reactivation_enabled).to eq(true)
      expect(setting.delivery_channel).to eq("manual")
      expect(setting.delivery_channel_label).to eq("手動コピー")
    end

    it "保存済み設定がある場合はそれを返すこと" do
      saved_setting = create(:learning_notification_setting, customer: customer,
                                                             reminder_enabled: false)

      expect(described_class.effective_for(customer)).to eq(saved_setting)
    end
  end

  describe "validations" do
    it "delivery_channel は想定値だけ許可すること" do
      setting = build(:learning_notification_setting, delivery_channel: "sms")

      expect(setting).not_to be_valid
      expect(setting.errors[:delivery_channel]).to be_present
    end
  end
end
