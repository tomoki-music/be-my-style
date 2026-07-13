require 'rails_helper'

RSpec.describe "Public::Homes", type: :request do
  describe "GET / (root)" do
    context "未ログインの場合" do
      before { get root_path }

      it "200 OKでゲスト向けLPを表示すること" do
        expect(response.status).to eq 200
      end

      it "「音楽で、世界とつながる。」がヒーローの主役として表示されること" do
        expect(response.body).to include("音楽で、")
        expect(response.body).to include("世界とつながる。")
      end

      it "新規登録CTAが /customers/sign_up を指すこと" do
        expect(response.body).to include(%(href="#{new_customer_registration_path}"))
      end

      it "「AI歌唱診断を試す」CTAが新規登録画面(singingドメイン)を指すこと" do
        expect(response.body).to include(%(href="#{new_singing_customer_registration_path}"))
        expect(new_singing_customer_registration_path).to eq("/singing/sign_up")
      end

      it "「AI歌唱診断を試す」CTAが診断作成画面やログイン画面へ直接遷移しないこと" do
        expect(response.body).not_to include(%(href="#{new_singing_diagnosis_path}"))
        expect(response.body).not_to include(%(href="#{new_customer_session_path}"))
      end

      it "フッターのコミュニティリンクがコミュニティ一覧(public_communities_path)を指すこと" do
        expect(response.body).to include(%(href="#{public_communities_path}"))
      end

      it "フッターのイベントリンクがイベント一覧(public_events_path)を指すこと" do
        expect(response.body).to include(%(href="#{public_events_path}"))
      end

      it "オフラインイベントの開催地域(埼玉中心・一部東京)とオンライン全国対応が明記されていること" do
        expect(response.body).to include("埼玉県を中心に開催")
        expect(response.body).to include("東京都内での開催")
        expect(response.body).to include("全国")
      end

      it "利用料金(基本無料・イベント別途参加費・有料オプション任意)が明記されていること" do
        expect(response.body).to include("基本利用は無料")
        expect(response.body).to include("イベントごとに別途参加費")
        expect(response.body).to include("有料オプションへの加入は任意")
      end

      it "FAQに料金に関する質問と回答が含まれること" do
        expect(response.body).to include("利用料金はかかりますか？")
        expect(response.body).to include("基本機能は無料でご利用いただけます")
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
        expect(response.body).not_to include("世界とつながる。")
      end
    end
  end
end
