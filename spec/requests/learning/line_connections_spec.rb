require "cgi"
require "rails_helper"

RSpec.describe "Learning line connections", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let(:teacher) { create(:customer, domain_name: "learning", confirmed_at: Time.current) }
  let(:student) { create(:learning_student, customer: teacher, nickname: "ギターさん") }

  around do |example|
    original_line_id = ENV["LINE_OFFICIAL_ACCOUNT_ID"]
    ENV.delete("LINE_OFFICIAL_ACCOUNT_ID")
    example.run
    ENV["LINE_OFFICIAL_ACCOUNT_ID"] = original_line_id
  end

  before { sign_in teacher }

  describe "GET /learning/students/:student_id/line_connection" do
    it "顧問がLINE連携QRの発行画面を見られること" do
      get learning_student_line_connection_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ギターさん さんのLINE連携")
      expect(response.body).to include("LINE連携QRを発行")
    end

    it "有効なトークンがある場合はQR SVGを表示すること" do
      connection = create(:learning_line_connection, customer: teacher, learning_student: student, line_user_id: nil)
      connection.issue_connect_token!

      get learning_student_line_connection_path(student)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("learning-line-qr__svg")
      expect(response.body).to include("LINE連携QRコード")
      expect(response.body).to include(connection.connect_token)
    end
  end

  describe "POST /learning/students/:student_id/line_connection" do
    it "生徒ごとの接続トークンを発行すること" do
      expect {
        post learning_student_line_connection_path(student)
      }.to change(Learning::LineConnection, :count).by(1)

      connection = Learning::LineConnection.last
      expect(response).to redirect_to(learning_student_line_connection_path(student))
      expect(connection.learning_student).to eq(student)
      expect(connection.connect_token).to be_present
      expect(connection.expires_at).to be > Time.current
    end

    it "再発行時は同じ生徒のトークンを更新すること" do
      post learning_student_line_connection_path(student)
      connection = Learning::LineConnection.last
      old_token = connection.connect_token

      expect {
        post learning_student_line_connection_path(student)
      }.not_to change(Learning::LineConnection, :count)

      expect(connection.reload.connect_token).to be_present
      expect(connection.connect_token).not_to eq(old_token)
    end
  end

  describe "GET /learning/line/connect" do
    it "有効なトークンならLINEへ送る連携メッセージを表示すること" do
      post learning_student_line_connection_path(student)
      connection = Learning::LineConnection.last

      get learning_line_connect_path(token: connection.connect_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("LINE連携はこちら")
      expect(response.body).to include("token=#{connection.connect_token}")
      expect(response.body).to include("LINE公式アカウントIDが未設定")
      expect(connection.reload).not_to be_connected
    end

    it "LINE_OFFICIAL_ACCOUNT_ID設定時はBot直送deep linkを表示すること" do
      ENV["LINE_OFFICIAL_ACCOUNT_ID"] = "@testbot"
      post learning_student_line_connection_path(student)
      connection = Learning::LineConnection.last
      encoded_text = CGI.escape("BeMyStyle LINE連携 token=#{connection.connect_token}")

      get learning_line_connect_path(token: connection.connect_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://line.me/R/oaMessage/%40testbot/?#{encoded_text}")
      expect(response.body).to include("メッセージが自動入力")
      expect(response.body).not_to include("https://line.me/R/share?text=")
      expect(response.body).not_to include("https://line.me/R/msg/text/")
    end

    it "無効なトークンならエラー表示すること" do
      post learning_student_line_connection_path(student)
      connection = Learning::LineConnection.last.update!(connect_token: nil, expires_at: nil)

      get learning_line_connect_path(token: "invalid-token")
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("LINE連携リンクが使えません")
    end

    it "期限切れトークンは使えないこと" do
      post learning_student_line_connection_path(student)
      connection = Learning::LineConnection.last
      connection.update!(expires_at: 1.minute.ago)

      get learning_line_connect_path(token: connection.connect_token)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(connection.reload).not_to be_connected
    end
  end

  describe "GET /learning/line/callback" do
    it "仮Callbackでも連携完了できること" do
      post learning_student_line_connection_path(student)
      connection = Learning::LineConnection.last

      get learning_line_callback_path(token: connection.connect_token)

      expect(response).to have_http_status(:ok)
      expect(connection.reload).to be_connected
    end
  end
end
