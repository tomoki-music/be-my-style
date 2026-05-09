require "rails_helper"

RSpec.describe "Learning line webhooks", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:student) { create(:learning_student, customer: teacher, nickname: "ギターさん") }
  let(:channel_secret) { "line-channel-secret-for-spec" }

  around do |example|
    original_secret = ENV["LINE_CHANNEL_SECRET"]
    ENV.delete("LINE_CHANNEL_SECRET")
    example.run
    ENV["LINE_CHANNEL_SECRET"] = original_secret
  end

  describe "POST /learning/line/webhook" do
    it "LINE_CHANNEL_SECRET未設定なら安全に失敗すること" do
      post learning_line_webhook_path,
           params: webhook_body("events" => []),
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => "invalid" }

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)["status"]).to eq("not_configured")
    end

    it "署名が不正なら処理しないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!

      post learning_line_webhook_path,
           params: webhook_body(message_event(connection.connect_token)),
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => "invalid" }

      expect(response).to have_http_status(:unauthorized)
      expect(connection.reload).not_to be_connected
    end

    it "messageイベントのtokenから本物のline_user_idを保存すること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!
      body = webhook_body(message_event(connection.connect_token, user_id: "UrealLineUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("status" => "ok", "processed" => 1, "connected" => 1)
      expect(connection.reload).to be_connected
      expect(connection.line_user_id).to eq("UrealLineUserId")
      expect(connection.connect_token).to be_nil
      expect(connection.expires_at).to be_nil
    end

    it "postbackイベントのtokenから本物のline_user_idを保存すること" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!
      body = webhook_body(postback_event(connection.connect_token, user_id: "UpostbackLineUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(connection.reload.line_user_id).to eq("UpostbackLineUserId")
    end

    it "followイベントだけではtokenがないため紐付けないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!
      body = webhook_body(follow_event(user_id: "UfollowLineUserId"))

      post learning_line_webhook_path,
           params: body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["connected"]).to eq(0)
      expect(connection.reload).not_to be_connected
    end

    it "使用済みtokenは再利用できないこと" do
      ENV["LINE_CHANNEL_SECRET"] = channel_secret
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!
      token = connection.connect_token
      first_body = webhook_body(message_event(token, user_id: "UfirstLineUserId"))
      second_body = webhook_body(message_event(token, user_id: "UsecondLineUserId"))

      post learning_line_webhook_path,
           params: first_body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(first_body) }
      post learning_line_webhook_path,
           params: second_body,
           headers: { "CONTENT_TYPE" => "application/json", "X-Line-Signature" => signature_for(second_body) }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["connected"]).to eq(0)
      expect(connection.reload.line_user_id).to eq("UfirstLineUserId")
    end
  end

  def webhook_body(*events)
    { destination: "UbotDestination", events: events.flatten }.to_json
  end

  def message_event(token, user_id: "UrealLineUserId")
    {
      type: "message",
      source: { type: "user", userId: user_id },
      message: { type: "text", text: "BeMyStyle LINE連携 token=#{token}" }
    }
  end

  def postback_event(token, user_id:)
    {
      type: "postback",
      source: { type: "user", userId: user_id },
      postback: { data: "token=#{token}" }
    }
  end

  def follow_event(user_id:)
    {
      type: "follow",
      source: { type: "user", userId: user_id }
    }
  end

  def signature_for(body)
    Base64.strict_encode64(
      OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), channel_secret, body)
    )
  end
end
