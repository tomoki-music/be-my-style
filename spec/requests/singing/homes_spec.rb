require 'rails_helper'

RSpec.describe "Singing::Homes", type: :request do
  let(:singing_customer) { FactoryBot.create(:customer, domain_name: "singing") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: singing_customer, domain: singing_domain)
  end

  describe "GET /singing" do
    it "歌唱・演奏診断LPをプラットフォームTOPとして表示すること" do
      sign_in singing_customer

      get singing_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("歌声の今を知る")
      expect(response.body).to include("歌唱・演奏診断プラン")
      expect(response.body).to include("診断履歴を見る")
    end
  end
end
