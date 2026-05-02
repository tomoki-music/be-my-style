require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:music_domain)    { Domain.find_or_create_by!(name: "music") }
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let!(:singing_domain)  { Domain.find_or_create_by!(name: "singing") }

  let(:music_customer) do
    FactoryBot.create(:customer, domain_name: "music", confirmed_at: Time.current, onboarding_done: true)
  end
  let(:business_customer) do
    FactoryBot.create(:customer, domain_name: "business", confirmed_at: Time.current, onboarding_done: true)
  end
  let(:learning_customer) do
    FactoryBot.create(:customer, domain_name: "learning", confirmed_at: Time.current)
  end
  let(:singing_customer) do
    FactoryBot.create(:customer, domain_name: "singing", confirmed_at: Time.current)
  end

  let(:admin_customer) do
    c = FactoryBot.create(:customer, confirmed_at: Time.current, onboarding_done: true, is_owner: :admin)
    CustomerDomain.find_or_create_by!(customer: c, domain: music_domain)
    CustomerDomain.find_or_create_by!(customer: c, domain: business_domain)
    CustomerDomain.find_or_create_by!(customer: c, domain: singing_domain)
    c
  end

  describe "POST /customers/sign_in (音楽ログイン)" do
    it "musicユーザーは音楽トップへリダイレクトされること" do
      post customer_session_path, params: {
        customer: { email: music_customer.email, password: "password" }
      }

      expect(response).to redirect_to(root_path)
    end

    it "管理者が音楽ログインしても音楽トップへリダイレクトされること" do
      post customer_session_path, params: {
        customer: { email: admin_customer.email, password: "password" }
      }

      expect(response).to redirect_to(root_path)
    end

    it "business/singing両方持つ管理者が音楽ログインしてもビジネスに飛ばされないこと" do
      post customer_session_path, params: {
        customer: { email: admin_customer.email, password: "password" }
      }

      expect(response).not_to redirect_to(business_root_path)
      expect(response).not_to redirect_to(singing_root_path)
    end
  end

  describe "POST /business/sign_in (ビジネスログイン)" do
    it "businessユーザーはビジネストップへリダイレクトされること" do
      post business_customer_session_path, params: {
        customer: { email: business_customer.email, password: "password" }
      }

      expect(response).to redirect_to(business_root_path)
    end

    it "管理者がビジネスログインするとビジネストップへリダイレクトされること" do
      post business_customer_session_path, params: {
        customer: { email: admin_customer.email, password: "password" }
      }

      expect(response).to redirect_to(business_root_path)
    end

    it "business未登録ユーザーはjoinへ遷移すること" do
      post business_customer_session_path, params: {
        customer: { email: music_customer.email, password: "password" }
      }

      expect(response).to redirect_to(business_join_path)
    end
  end

  describe "POST /learning/sign_in (学習ログイン)" do
    it "learningユーザーは学習トップへリダイレクトされること" do
      post learning_customer_session_path, params: {
        customer: { email: learning_customer.email, password: "password" }
      }

      expect(response).to redirect_to(learning_root_path)
    end

    it "learning未登録ユーザーはjoinへ遷移すること" do
      post learning_customer_session_path, params: {
        customer: { email: music_customer.email, password: "password" }
      }

      expect(response).to redirect_to(learning_join_path)
    end
  end

  describe "POST /singing/sign_in (診断ログイン)" do
    it "singingユーザーは診断トップへリダイレクトされること" do
      post singing_customer_session_path, params: {
        customer: { email: singing_customer.email, password: "password" }
      }

      expect(response).to redirect_to(singing_root_path)
    end

    it "管理者が診断ログインすると診断トップへリダイレクトされること" do
      post singing_customer_session_path, params: {
        customer: { email: admin_customer.email, password: "password" }
      }

      expect(response).to redirect_to(singing_root_path)
    end

    it "singing未登録ユーザーはjoinへ遷移すること" do
      post singing_customer_session_path, params: {
        customer: { email: music_customer.email, password: "password" }
      }

      expect(response).to redirect_to(singing_join_path)
    end
  end

  describe "ログアウト後の再ログインで別ドメインに引っ張られないこと" do
    it "singing共通ヘッダーのログアウトはDELETE formで表示されること" do
      sign_in singing_customer

      get singing_diagnoses_path

      expect(response.body).to include("singing-nav__logout-form")
      expect(response.body).to include(%(action="#{destroy_customer_session_path}"))
      expect(response.body).to include(%(name="_method"))
      expect(response.body).to include(%(value="delete"))
    end

    it "businessからログアウト後、音楽でログインしても音楽トップへ戻ること" do
      sign_in admin_customer
      delete destroy_customer_session_path, headers: { "HTTP_REFERER" => business_root_path }

      post customer_session_path, params: {
        customer: { email: admin_customer.email, password: "password" }
      }

      expect(response).to redirect_to(root_path)
    end

    it "singingからログアウト後、音楽でログインしても音楽トップへ戻ること" do
      sign_in admin_customer
      delete destroy_customer_session_path, headers: { "HTTP_REFERER" => singing_root_path }

      post customer_session_path, params: {
        customer: { email: admin_customer.email, password: "password" }
      }

      expect(response).to redirect_to(root_path)
    end
  end
end
