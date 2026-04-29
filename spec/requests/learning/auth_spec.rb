require "rails_helper"

RSpec.describe "Learning auth", type: :request do
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }

  let(:learning_customer) do
    FactoryBot.create(:customer, domain_name: "learning", confirmed_at: Time.current)
  end
  let(:music_customer) do
    FactoryBot.create(:customer, domain_name: "music", confirmed_at: Time.current, onboarding_done: true)
  end

  describe "GET /learning/sign_in" do
    it "専用ログイン画面を表示する" do
      get new_learning_customer_session_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Learningドメインの管理画面へようこそ")
    end
  end

  describe "GET /learning/sign_up" do
    it "専用新規登録画面を表示する" do
      get new_learning_customer_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("生徒の進捗管理を始めるアカウントを作成します")
    end
  end

  describe "GET /learning/password/new" do
    it "専用パスワード再設定画面を表示する" do
      get new_learning_customer_password_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("登録メールアドレスに再設定案内を送信します")
    end
  end

  describe "POST /learning/sign_in" do
    it "learningユーザーは learning_root_path へ進む" do
      post learning_customer_session_path, params: {
        customer: { email: learning_customer.email, password: "password" }
      }

      expect(response).to redirect_to(learning_root_path)
    end

    it "learning未登録ユーザーは join へ遷移する" do
      post learning_customer_session_path, params: {
        customer: { email: music_customer.email, password: "password" }
      }

      expect(response).to redirect_to(learning_join_path)
    end
  end

  describe "GET /learning/join" do
    it "未認証時は learning 専用ログインへリダイレクトされる" do
      get learning_join_path

      expect(response).to redirect_to(new_learning_customer_session_path)
    end

    it "認証済みなら確認画面を表示する" do
      sign_in music_customer
      get learning_join_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Learningドメインの利用を開始しますか？")
    end

    it "既存権限ありユーザーは learning_root_path へ戻る" do
      sign_in learning_customer

      get learning_join_path

      expect(response).to redirect_to(learning_root_path)
    end
  end

  describe "POST /learning/join" do
    before { sign_in music_customer }

    it "learningドメインを付与する" do
      expect {
        post learning_join_path
      }.to change { music_customer.domains.reload.exists?(name: "learning") }.from(false).to(true)
    end

    it "learning_root_path へリダイレクトする" do
      post learning_join_path

      expect(response).to redirect_to(learning_root_path)
    end

    it "2回POSTしてもCustomerDomainが重複しない" do
      post learning_join_path

      expect {
        post learning_join_path
      }.not_to change { CustomerDomain.where(customer: music_customer, domain: learning_domain).count }
    end
  end

  describe "POST /customers/sign_in" do
    it "music正式導線は learning_join へ変わらない" do
      post customer_session_path, params: {
        customer: { email: music_customer.email, password: "password" }
      }

      expect(response).not_to redirect_to(learning_join_path)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE /customers/sign_out" do
    it "learning配下からのログアウト後は learning 専用ログインへ戻る" do
      sign_in learning_customer

      delete destroy_customer_session_path, headers: { "HTTP_REFERER" => learning_root_path }

      expect(response).to redirect_to(new_learning_customer_session_path)
    end
  end
end
