require 'rails_helper'

RSpec.describe "Public::Homes", type: :request do
  describe "GET / (root)" do
    context "未ログインの場合" do
      before { get root_path }

      it "200 OKでゲスト向けLPを表示すること" do
        expect(response.status).to eq 200
        expect(response.body).to include("あなたの音楽人生は")
      end

      it "新規登録CTAが /customers/sign_up を指すこと" do
        expect(response.body).to include(new_customer_registration_path)
      end

      it "AI歌唱診断CTAが /singing/diagnoses/new を指すこと" do
        expect(response.body).to include(new_singing_diagnosis_path)
      end

      it "フッターのコミュニティリンクがコミュニティ一覧(public_communities_path)を指すこと" do
        expect(response.body).to include(%(href="#{public_communities_path}"))
      end

      it "フッターのイベントリンクがイベント一覧(public_events_path)を指すこと" do
        expect(response.body).to include(%(href="#{public_events_path}"))
      end
    end

    context "ログイン済みの場合" do
      let!(:customer) { create(:customer, :customer_with_parts) }

      before do
        sign_in customer
        get root_path
      end

      it "200 OKで従来のホーム画面(top.html.haml)を表示すること" do
        expect(response.status).to eq 200
        expect(response.body).not_to include("あなたの音楽人生は")
      end
    end
  end
end
