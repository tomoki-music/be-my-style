require "rails_helper"

RSpec.describe Learning::NotificationLog, type: :model do
  describe "associations" do
    it "customer と learning_student に紐づくこと" do
      log = build(:learning_notification_log)

      expect(log.customer).to be_present
      expect(log.learning_student).to be_present
    end

    it "learning_student は任意であること" do
      log = build(:learning_notification_log, learning_student: nil)

      expect(log).to be_valid
    end
  end

  describe "validations" do
    it "必須項目が揃っていれば有効であること" do
      expect(build(:learning_notification_log)).to be_valid
    end

    it "customer は必須であること" do
      log = build(:learning_notification_log, customer: nil)

      expect(log).not_to be_valid
    end

    it "notification_type は許可された値のみ有効であること" do
      log = build(:learning_notification_log, notification_type: "unknown")

      expect(log).not_to be_valid
    end

    it "delivery_channel は必須であること" do
      log = build(:learning_notification_log, delivery_channel: nil)

      expect(log).not_to be_valid
    end

    it "status は必須であること" do
      log = build(:learning_notification_log, status: nil)

      expect(log).not_to be_valid
    end

    it "message は必須であること" do
      log = build(:learning_notification_log, message: nil)

      expect(log).not_to be_valid
    end
  end
end
