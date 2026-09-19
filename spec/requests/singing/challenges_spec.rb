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

    it "GrowthType Communityの実データではない固定人数(「人の仲間」)を表示しないこと" do
      get singing_challenges_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("人の仲間")
      expect(response.body).not_to include("growth-type-community__count")
    end

    it "GrowthType Communityのカード自体（名称・CTA）は表示され続けること" do
      get singing_challenges_path

      doc = Nokogiri::HTML(response.body)
      section = doc.at_css(".growth-type-community")

      expect(response).to have_http_status(:ok)
      expect(section).to be_present
      expect(section.at_css(".growth-type-community__eyebrow").text).to eq("GrowthType Community")
      expect(section.at_css(".growth-type-community__title")).to be_present
      expect(section.at_css(".growth-type-community__message")).to be_present
      expect(section.at_css(".growth-type-community__button")).to be_present
    end
  end
end
