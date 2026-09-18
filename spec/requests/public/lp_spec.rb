require 'rails_helper'

RSpec.describe "Public::Lps", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/public/lp/index"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("特定商取引法に基づく表記")
      expect(response.body).to include("利用規約")
      expect(response.body).to include("プライバシーポリシー")
    end
  end

  describe "GET /public/lp/singing" do
    it "歌唱・演奏診断LPを表示できること" do
      get public_singing_lp_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("歌唱・演奏診断プラン")
      expect(response.body).to include("診断を始める").or include("無料登録して診断する")
      expect(response.body).to include("「うまいのにバンドだと微妙」を、アンサンブル力から見える化。")
      expect(response.body).to include("バンド演奏診断では、音量バランス、リズムの揃い、グルーヴ、役割理解、抑揚、一体感をもとに、バンド全体のまとまりを診断します。")
      expect(response.body).to include("今週のバンド練習テーマ")
      expect(response.body).to include("特定商取引法に基づく表記")
      expect(response.body).to include("利用規約")
      expect(response.body).to include("プライバシーポリシー")
    end

    it "イベントオーナー(コミュニティオーナー)のfreeユーザーには特典表示と5回分の残数を表示し、LIGHTへの誘導は表示しないこと" do
      singing_domain = Domain.find_or_create_by!(name: "singing")
      customer = FactoryBot.create(:customer, domain_name: "singing")
      CustomerDomain.find_or_create_by!(customer: customer, domain: singing_domain)
      FactoryBot.create(:community, owner_id: customer.id)
      sign_in customer

      get public_singing_lp_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("イベントオーナーのため、今月は5回まで診断できます")
      expect(response.body).to include("5 / 5回")
      expect(response.body).not_to include("LIGHTで5回/月に増やす")
    end
  end
end
