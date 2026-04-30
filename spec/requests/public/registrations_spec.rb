require "rails_helper"

RSpec.describe "Public::Registrations", type: :request do
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  describe "GET /customers/sign_up" do
    it "音楽だけを選択肢として表示する" do
      get new_customer_registration_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("音楽")
      expect(response.body).not_to include("ビジネス")
      expect(response.body).not_to include("学習")
    end

    it "音楽向けの入力項目だけを表示する" do
      get new_customer_registration_path

      expect(response.body).to include("パート")
      expect(response.body).to include("ジャンル")
      expect(response.body).to include("好きなアーティスト")
      expect(response.body).not_to include("ビジネスプロフィール")
      expect(response.body).not_to include("学習向けアカウント")
    end

    it "パスワード確認欄を表示する" do
      get new_customer_registration_path

      expect(response.body).to include("パスワード確認")
      expect(response.body).to include("customer_password_confirmation")
    end
  end

  describe "POST /customers" do
    it "password と password_confirmation が一致すれば登録できる" do
      expect {
        post customer_registration_path, params: {
          customer: {
            email: "music-password-match@example.com",
            password: "password",
            password_confirmation: "password",
            name: "music user"
          }
        }
      }.to change(Customer, :count).by(1)

      customer = Customer.last
      expect(customer.has_domain?("music")).to be(true)
      expect(customer.has_domain?("learning")).to be(false)
      expect(customer.has_domain?("singing")).to be(false)
      expect(response).to redirect_to(verify_path)
    end

    it "password と password_confirmation が一致しなければ登録エラーになる" do
      expect {
        post customer_registration_path, params: {
          customer: {
            email: "music-password-mismatch@example.com",
            password: "password",
            password_confirmation: "different",
            name: "music user"
          }
        }
      }.not_to change(Customer, :count)

      expect(response.body).to include("パスワード")
    end

    it "domain_name を business にして送っても music として登録される" do
      expect {
        post customer_registration_path, params: {
          customer: {
            email: "music-only@example.com",
            password: "password",
            password_confirmation: "password",
            name: "music user",
            domain_name: "business"
          }
        }
      }.to change(Customer, :count).by(1)

      customer = Customer.last
      expect(customer.domains.pluck(:name)).to include("music")
      expect(customer.domains.pluck(:name)).not_to include("business")
      expect(response).to redirect_to(verify_path)
    end
  end

  describe "POST /learning/sign_up" do
    it "learning 登録ユーザーには learning domain だけを付与する" do
      expect {
        post learning_customer_registration_path, params: {
          customer: {
            email: "learning-domain@example.com",
            password: "password",
            password_confirmation: "password",
            name: "learning user"
          }
        }
      }.to change(Customer, :count).by(1)

      customer = Customer.last
      expect(customer.has_domain?("music")).to be(false)
      expect(customer.has_domain?("learning")).to be(true)
      expect(customer.has_domain?("singing")).to be(false)
      expect(response).to redirect_to(new_learning_customer_session_path)
    end
  end
end
