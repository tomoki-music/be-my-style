require 'rails_helper'

RSpec.describe "Public::Lps", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/public/lp/index"
      expect(response).to have_http_status(:success)
    end
  end

end
