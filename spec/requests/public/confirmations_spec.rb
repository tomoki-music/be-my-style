require 'rails_helper'
require 'cgi'
require 'uri'

RSpec.describe "Public::Confirmations", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let!(:singing_domain)  { Domain.find_or_create_by!(name: "singing") }
  let!(:music_domain)    { Domain.find_or_create_by!(name: "music") }

  # unconfirmed な Customer を直接作成（Devise の confirmation_token を使う）
  def build_unconfirmed_customer(domain_name:)
    customer = FactoryBot.build(:customer, domain_name: domain_name, confirmed_at: nil)
    customer.skip_confirmation_notification!
    customer.save!(validate: false)
    domain = Domain.find_by!(name: domain_name)
    CustomerDomain.find_or_create_by!(customer: customer, domain: domain)
    customer.send_confirmation_instructions
    customer.reload
  end

  def attach_domain(customer, domain)
    CustomerDomain.find_or_create_by!(customer: customer, domain: domain)
    customer.reload
  end

  def confirmation_uri_from_last_mail
    mail_body = ActionMailer::Base.deliveries.last.body.decoded
    href = CGI.unescapeHTML(mail_body.match(/href="([^"]+)"/)[1])
    URI.parse(href)
  end

  def confirmation_request_path(uri)
    [uri.path, uri.query].compact.join("?")
  end

  def register_customer(path, email)
    post path, params: {
      customer: {
        email: email,
        password: "password",
        password_confirmation: "password",
        name: "confirmation user"
      }
    }
  end

  describe "GET /customers/confirmation?confirmation_token=xxx" do
    context "singingユーザーがメールアドレスを確認した場合" do
      it "singing_root_path へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "singing")

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(singing_root_path)
      end
    end

    context "musicユーザーがメールアドレスを確認した場合" do
      it "root_path（音楽TOP）へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "music")

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(root_path)
      end
    end

    context "businessユーザーがメールアドレスを確認した場合" do
      it "business_root_path へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "business")

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(business_root_path)
      end
    end

    context "learningユーザーがメールアドレスを確認した場合" do
      it "learning_root_path へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "learning")

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(learning_root_path)
      end
    end

    context "複数ドメインを持つユーザーがメールアドレスを確認した場合" do
      it "business と singing を持つユーザーは business_root_path へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "business")
        attach_domain(customer, singing_domain)

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(business_root_path)
      end

      it "learning と singing を持つユーザーは learning_root_path へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "learning")
        attach_domain(customer, singing_domain)

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(learning_root_path)
      end

      it "music と singing を持つユーザーは root_path（音楽TOP）へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "music")
        attach_domain(customer, singing_domain)

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "登録後に送信される確認メールリンク経由の確認" do
    before { ActionMailer::Base.deliveries.clear }

    it "music 登録メールのリンクは public/confirmations#show に届き、音楽TOPへリダイレクトされる" do
      register_customer(customer_registration_path, "music-confirmation-link@example.com")
      customer = Customer.find_by!(email: "music-confirmation-link@example.com")
      uri = confirmation_uri_from_last_mail

      expect(uri.path).to eq(customer_confirmation_path)
      expect(uri.path).not_to start_with("/singing")
      expect(customer.has_domain?("music")).to be(true)
      expect(customer.has_domain?("singing")).to be(false)

      get confirmation_request_path(uri)

      expect(controller.controller_path).to eq("public/confirmations")
      expect(response).to redirect_to(root_path)
    end

    it "learning 登録メールのリンクは public/confirmations#show に届き、学習TOPへリダイレクトされる" do
      register_customer(learning_customer_registration_path, "learning-confirmation-link@example.com")
      customer = Customer.find_by!(email: "learning-confirmation-link@example.com")
      uri = confirmation_uri_from_last_mail

      expect(uri.path).to eq(customer_confirmation_path)
      expect(uri.path).not_to start_with("/singing")
      expect(customer.has_domain?("learning")).to be(true)
      expect(customer.has_domain?("singing")).to be(false)

      get confirmation_request_path(uri)

      expect(controller.controller_path).to eq("public/confirmations")
      expect(response).to redirect_to(learning_root_path)
    end

    it "business 登録メールのリンクは public/confirmations#show に届き、ビジネスTOPへリダイレクトされる" do
      register_customer(business_customer_registration_path, "business-confirmation-link@example.com")
      customer = Customer.find_by!(email: "business-confirmation-link@example.com")
      uri = confirmation_uri_from_last_mail

      expect(uri.path).to eq(customer_confirmation_path)
      expect(uri.path).not_to start_with("/singing")
      expect(customer.has_domain?("business")).to be(true)
      expect(customer.has_domain?("singing")).to be(false)

      get confirmation_request_path(uri)

      expect(controller.controller_path).to eq("public/confirmations")
      expect(response).to redirect_to(business_root_path)
    end

    it "singing 登録メールのリンクは public/confirmations#show に届き、歌唱・演奏診断TOPへリダイレクトされる" do
      register_customer(singing_customer_registration_path, "singing-confirmation-link@example.com")
      customer = Customer.find_by!(email: "singing-confirmation-link@example.com")
      uri = confirmation_uri_from_last_mail

      expect(uri.path).to eq(customer_confirmation_path)
      expect(customer.has_domain?("singing")).to be(true)

      get confirmation_request_path(uri)

      expect(controller.controller_path).to eq("public/confirmations")
      expect(response).to redirect_to(singing_root_path)
    end

    it "既存の singing セッションがあっても music 登録メールのリンクは音楽TOPへ到達する" do
      register_customer(customer_registration_path, "music-with-stale-session@example.com")
      uri = confirmation_uri_from_last_mail
      sign_in FactoryBot.create(:customer, domain_name: "singing", confirmed_at: Time.current)

      get confirmation_request_path(uri)

      expect(controller.controller_path).to eq("public/confirmations")
      expect(response).to redirect_to(root_path)

      follow_redirect!

      expect(controller.controller_path).to eq("public/homes")
      expect(response).to have_http_status(:ok)
    end

    it "既存の singing セッションがあっても learning 登録メールのリンクは学習TOPへ到達する" do
      register_customer(learning_customer_registration_path, "learning-with-stale-session@example.com")
      uri = confirmation_uri_from_last_mail
      sign_in FactoryBot.create(:customer, domain_name: "singing", confirmed_at: Time.current)

      get confirmation_request_path(uri)

      expect(controller.controller_path).to eq("public/confirmations")
      expect(response).to redirect_to(learning_root_path)

      follow_redirect!

      expect(controller.controller_path).to eq("learning/dashboards")
      expect(response).to have_http_status(:ok)
    end
  end
end
