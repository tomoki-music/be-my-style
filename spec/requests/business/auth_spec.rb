require "rails_helper"

RSpec.describe "Business auth", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }

  let(:business_customer) do
    FactoryBot.create(:customer, domain_name: "business", confirmed_at: Time.current, onboarding_done: true)
  end
  let(:music_customer) do
    FactoryBot.create(:customer, domain_name: "music", confirmed_at: Time.current, onboarding_done: true)
  end

  describe "GET /business/sign_in" do
    it "専用ログイン画面を表示する" do
      get new_business_customer_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("NAKAMA ビジネスコミュニティへようこそ")
    end
  end

  describe "GET /business/sign_up" do
    it "専用新規登録画面を表示する" do
      get new_business_customer_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("投稿・プロジェクト・コミュニティを始めましょう")
    end
  end

  describe "GET /business/password/new" do
    it "専用パスワード再設定画面を表示する" do
      get new_business_customer_password_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("登録メールアドレス宛に再設定用メールをお送りします")
    end
  end

  describe "POST /business/sign_in" do
    it "businessユーザーは既存遷移先へ進む" do
      post business_customer_session_path, params: {
        customer: { email: business_customer.email, password: "password" }
      }

      expect(response).to redirect_to(business_root_path)
    end

    it "business未登録ユーザーは join へ遷移する" do
      post business_customer_session_path, params: {
        customer: { email: music_customer.email, password: "password" }
      }

      expect(response).to redirect_to(business_join_path)
    end
  end

  describe "GET /business/join" do
    it "未認証時は business 専用ログインへリダイレクトされる" do
      get business_join_path

      expect(response).to redirect_to(new_business_customer_session_path)
    end

    it "認証済みなら確認画面を表示する" do
      sign_in music_customer
      get business_join_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Businessドメインの利用を開始しますか？")
    end

    it "既存権限ありユーザーは business_root_path へ戻る" do
      sign_in business_customer

      get business_join_path

      expect(response).to redirect_to(business_root_path)
    end
  end

  describe "POST /business/join" do
    before { sign_in music_customer }

    it "businessドメインを付与する" do
      expect {
        post business_join_path
      }.to change { music_customer.domains.reload.exists?(name: "business") }.from(false).to(true)
    end

    it "business_root_path へリダイレクトする" do
      post business_join_path

      expect(response).to redirect_to(business_root_path)
    end

    it "2回POSTしてもCustomerDomainが重複しない" do
      post business_join_path

      expect {
        post business_join_path
      }.not_to change { CustomerDomain.where(customer: music_customer, domain: business_domain).count }
    end
  end

  describe "POST /customers/sign_in" do
    it "music正式導線は business_join へ変わらない" do
      post customer_session_path, params: {
        customer: { email: music_customer.email, password: "password" }
      }

      expect(response).not_to redirect_to(business_join_path)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /customers/sign_out" do
    it "business配下からのログアウト後は business 専用ログインへ戻る" do
      sign_in business_customer

      delete destroy_customer_session_path, headers: { "HTTP_REFERER" => business_root_path }

      expect(response).to redirect_to(new_business_customer_session_path)
    end
  end
end
