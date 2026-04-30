require 'rails_helper'

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
end
