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
        expect(response.body).to include("東京都内で開催する場合があります")
        expect(response.body).to include("全国")
      end

      it "感情的な中核メッセージ(一人では出会えなかった仲間と、音楽と、未来へ)が表示されること" do
        expect(response.body).to include("一人では出会えなかった")
        expect(response.body).to include("仲間と、音楽と、未来へ。")
      end

      it "AIが主役に戻っていないこと(ヒーローで巨大なAI表示がなく、Journeyでも手段として扱われること)" do
        expect(response.body).not_to include(%(class="glp-score-num"))
        expect(response.body).to include("AIは、自分を知るための手段のひとつ")
      end

      it "Journeyが歌う・演奏するから始まり、AI診断を手段として2番目に扱う順序で表示されること" do
        idx_step1 = response.body.index("好きな音楽を、今の自分のまま楽しむことから。")
        idx_step2 = response.body.index("AI歌唱診断などを通じて、自分の特徴や成長のきっかけを知る。")
        idx_step3 = response.body.index("コミュニティで、同じ音楽を楽しむ人とつながる。")
        idx_step4 = response.body.index("オンライン交流やオフラインイベントへ参加する。")
        idx_step5 = response.body.index("挑戦・成長・応援が、日常に広がっていく。")
        [idx_step1, idx_step2, idx_step3, idx_step4, idx_step5].each { |idx| expect(idx).not_to be_nil }
        expect([idx_step1, idx_step2, idx_step3, idx_step4, idx_step5]).to eq([idx_step1, idx_step2, idx_step3, idx_step4, idx_step5].sort)
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
