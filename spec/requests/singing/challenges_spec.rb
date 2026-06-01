require "rails_helper"

RSpec.describe "Singing::Challenges", type: :request do
  let(:customer) { create(:customer, domain_name: "singing") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: customer, domain: singing_domain)
    sign_in customer
  end

  describe "GET /singing/challenges" do
    it "今日の挑戦から仲間の成長へ循環する導線を表示する" do
      get singing_challenges_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今日の挑戦を見つける")
      expect(response.body).to include("今日のミッションに挑戦する")
      expect(response.body).to include("仲間の成長を見る")
      expect(response.body).to include("音楽コミュニティホームへ")
    end
  end
end
