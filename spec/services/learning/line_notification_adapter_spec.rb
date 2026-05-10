require "rails_helper"

RSpec.describe Learning::LineNotificationAdapter do
  let(:notification_log) { create(:learning_notification_log, delivery_channel: "line", status: "queued") }

  around do |example|
    original = ENV["LINE_CHANNEL_ACCESS_TOKEN"]
    ENV.delete("LINE_CHANNEL_ACCESS_TOKEN")
    example.run
    ENV["LINE_CHANNEL_ACCESS_TOKEN"] = original
  end

  describe "#enabled?" do
    it "LINE設定がなければ false を返すこと" do
      adapter = described_class.new

      expect(adapter.enabled?).to eq(false)
    end
  end

  describe "#build_payload" do
    it "通知ログからLINE用payloadを組み立てること" do
      create(:learning_student_training,
             customer: notification_log.customer,
             learning_student: notification_log.learning_student,
             title: "コードチェンジ練習")

      payload = described_class.new.build_payload(notification_log)
      text = payload[:messages].first[:text]

      expect(payload[:to]).to be_nil
      expect(payload[:messages].first[:type]).to eq("text")
      expect(text).to include(notification_log.message)
      expect(text).to include("▼ 今日やることを見る")
      expect(text).to include(notification_log.learning_student.public_access_token)
      expect(text).to include("コードチェンジ練習")
      expect(text).to include("やった")
    end

    it "継続日数に応じた文面を入れること" do
      3.downto(1) do |days_ago|
        create(:learning_progress_log,
               customer: notification_log.customer,
               learning_student: notification_log.learning_student,
               practiced_on: Date.current - days_ago.days)
      end

      payload = described_class.new.build_payload(notification_log)

      expect(payload[:messages].first[:text]).to include("3日継続中！いい流れです")
    end

    it "7日継続の文面を入れること" do
      7.downto(1) do |days_ago|
        create(:learning_progress_log,
               customer: notification_log.customer,
               learning_student: notification_log.learning_student,
               practiced_on: Date.current - days_ago.days)
      end

      payload = described_class.new.build_payload(notification_log)

      expect(payload[:messages].first[:text]).to include("1週間継続達成！かなり良い習慣になってきています")
    end

    it "連携済みLINE userIdを宛先にすること" do
      create(:learning_line_connection,
             customer: notification_log.customer,
             learning_student: notification_log.learning_student,
             line_user_id: "UrealLineUserId",
             status: "connected",
             connected_at: Time.current)

      payload = described_class.new.build_payload(notification_log)

      expect(payload[:to]).to eq("UrealLineUserId")
    end

    it "teacher_messageは先生の本文を中心にLINE文面を組み立てること" do
      teacher_message_log = create(:learning_notification_log,
                                   notification_type: "teacher_message",
                                   delivery_channel: "line",
                                   status: "queued",
                                   title: "先生からのメッセージ",
                                   message: "今日の練習、5分だけでもOK！",
                                   recommended_action: "先生からのメッセージです。")

      payload = described_class.new.build_payload(teacher_message_log)
      text = payload[:messages].first[:text]

      expect(text).to include("先生からのメッセージ")
      expect(text).to include("今日の練習、5分だけでもOK！")
      expect(text).to include("先生からのメッセージです。")
      expect(text).to include("▼ 生徒ページを開く")
      expect(text).to include(teacher_message_log.learning_student.public_access_token)
      expect(text).to include("やった")
    end

    it "teacher_bulk_messageは一括送信用のLINE文面を組み立てること" do
      teacher_bulk_message_log = create(:learning_notification_log,
                                        notification_type: "teacher_bulk_message",
                                        delivery_channel: "line",
                                        status: "queued",
                                        title: "先生からの一括メッセージ",
                                        message: "ライブまであと1週間！今日も5分だけ練習してみよう",
                                        recommended_action: "先生からの一括メッセージです。")

      payload = described_class.new.build_payload(teacher_bulk_message_log)
      text = payload[:messages].first[:text]

      expect(text).to include("先生からのメッセージです。")
      expect(text).to include("ライブまであと1週間！今日も5分だけ練習してみよう")
      expect(text).to include("▼ 生徒ページを見る")
      expect(text).to include(teacher_bulk_message_log.learning_student.public_access_token)
      expect(text).to include("やった！")
    end

    it "assignment_createdは課題配布用のLINE文面を組み立てること" do
      assignment_log = create(:learning_notification_log,
                              notification_type: "assignment_created",
                              delivery_channel: "line",
                              status: "queued",
                              title: "ライブ前基礎練習",
                              message: "・クロマチック\n・8ビート",
                              recommended_action: "期限: 2026/05/20")

      payload = described_class.new.build_payload(assignment_log)
      text = payload[:messages].first[:text]

      expect(text).to include("新しい課題が届きました")
      expect(text).to include("ライブ前基礎練習")
      expect(text).to include("・クロマチック")
      expect(text).to include("期限: 2026/05/20")
      expect(text).to include("▼ 生徒ページを見る")
      expect(text).to include(assignment_log.learning_student.public_access_token)
      expect(text).to include("やった！")
    end
  end

  describe "#deliver" do
    it "実送信せず、未設定結果とerror_messageを返すこと" do
      result = described_class.new.deliver(notification_log)

      expect(result.status).to eq(:adapter_disabled)
      expect(result.success?).to eq(false)
      expect(notification_log.reload.status).to eq("skipped")
      expect(notification_log.sent_at).to be_nil
      expect(notification_log.error_message).to eq("LINE adapter is not configured")
    end

    it "設定済みでもLINE未連携ならno-opで安全に失敗すること" do
      ENV["LINE_CHANNEL_ACCESS_TOKEN"] = "test-token"

      result = described_class.new.deliver(notification_log)

      expect(result.status).to eq(:no_recipient)
      expect(notification_log.reload.status).to eq("skipped")
      expect(notification_log.reload.error_message).to eq("LINE recipient is not connected")
    end

    it "設定済みかつLINE連携済みならLINE push messageを送信してsentにすること" do
      ENV["LINE_CHANNEL_ACCESS_TOKEN"] = "test-token"
      create(:learning_line_connection,
             customer: notification_log.customer,
             learning_student: notification_log.learning_student,
             line_user_id: "UrealLineUserId",
             status: "connected",
             connected_at: Time.current)
      http_client = fake_http_client(response: Net::HTTPOK.new("1.1", "200", "OK"))

      result = described_class.new(http_client: http_client).deliver(notification_log)

      expect(result.status).to eq(:ok)
      expect(result.payload[:to]).to eq("UrealLineUserId")
      expect(notification_log.reload.status).to eq("sent")
      expect(notification_log.sent_at).to be_present
      expect(http_client.request["Authorization"]).to eq("Bearer test-token")
      expect(JSON.parse(http_client.request.body)["to"]).to eq("UrealLineUserId")
    end

    it "HTTP失敗時はfailedと失敗理由を保存すること" do
      ENV["LINE_CHANNEL_ACCESS_TOKEN"] = "test-token"
      create(:learning_line_connection,
             customer: notification_log.customer,
             learning_student: notification_log.learning_student,
             line_user_id: "UrealLineUserId",
             status: "connected",
             connected_at: Time.current)
      response = Net::HTTPBadRequest.new("1.1", "400", "Bad Request")
      allow(response).to receive(:body).and_return("invalid request")

      result = described_class.new(http_client: fake_http_client(response: response)).deliver(notification_log)

      expect(result.status).to eq(:http_error)
      expect(notification_log.reload.status).to eq("failed")
      expect(notification_log.error_message).to include("status=400")
    end
  end

  def fake_http_client(response:)
    Class.new do
      attr_reader :request

      define_method(:initialize) do
        @response = response
      end

      define_method(:start) do |_host, _port, _options, &block|
        http = Object.new
        parent = self
        http.define_singleton_method(:request) do |request|
          parent.instance_variable_set(:@request, request)
          response
        end
        block.call(http)
      end
    end.new
  end
end
