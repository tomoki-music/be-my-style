require "rails_helper"

RSpec.describe Learning::LineNotificationAdapter do
  let(:notification_log) { create(:learning_notification_log, delivery_channel: "line", status: "queued") }

  around do |example|
    original = ENV["LINE_CHANNEL_ACCESS_TOKEN"]
    ENV.delete("LINE_CHANNEL_ACCESS_TOKEN")
    example.run
    ENV["LINE_CHANNEL_ACCESS_TOKEN"] = original
  end

  before do
    allow(Rails.application.credentials).to receive(:dig).with(:line, :channel_access_token).and_return(nil)
  end

  describe "#enabled?" do
    it "LINE設定がなければ false を返すこと" do
      adapter = described_class.new

      expect(adapter.enabled?).to eq(false)
    end
  end

  describe "#build_payload" do
    it "通知ログからLINE用payloadを組み立てること" do
      payload = described_class.new.build_payload(notification_log)

      expect(payload[:to]).to eq(notification_log.learning_student_id)
      expect(payload[:messages].first[:type]).to eq("text")
      expect(payload[:messages].first[:text]).to include(notification_log.message)
    end
  end

  describe "#deliver" do
    it "実送信せず、未設定結果とerror_messageを返すこと" do
      result = described_class.new.deliver(notification_log)

      expect(result.status).to eq(:adapter_disabled)
      expect(result.success?).to eq(false)
      expect(notification_log.reload.status).to eq("queued")
      expect(notification_log.sent_at).to be_nil
      expect(notification_log.error_message).to eq("LINE adapter is not configured")
    end
  end
end
