require "rails_helper"

RSpec.describe "Singing::GrowthFeeds", type: :request do
  let(:customer) { create(:customer, domain_name: "singing") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  before do
    CustomerDomain.find_or_create_by!(customer: customer, domain: singing_domain)
    sign_in customer
  end

  describe "GET /singing/growth_feed" do
    it "Growth Feed 2.0のヘッダーとサマリーを表示する" do
      create(:singing_diagnosis, :completed, customer: customer, overall_score: 70, created_at: Time.current)

      get singing_growth_feed_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("コミュニティの鼓動")
      expect(response.body).to include("今週の挑戦")
      expect(response.body).to include("応援が飛び交っています")
      expect(response.body).to include("Milestone")
    end
  end
end
