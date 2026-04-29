require 'rails_helper'

RSpec.describe "Public::Confirmations", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:learning_domain) { Domain.find_or_create_by!(name: "learning") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }
  let!(:music_domain)   { Domain.find_or_create_by!(name: "music") }

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

  describe "GET /customers/confirmation?confirmation_token=xxx" do
    context "singingユーザーがメールアドレスを確認した場合" do
      it "new_singing_customer_session_path へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "singing")

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(new_singing_customer_session_path)
      end
    end

    context "musicユーザーがメールアドレスを確認した場合" do
      it "new_customer_session_path（既存の /customers/sign_in）へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "music")

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(new_customer_session_path)
      end
    end

    context "businessユーザーがメールアドレスを確認した場合" do
      it "new_business_customer_session_path へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "business")

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(new_business_customer_session_path)
      end
    end

    context "learningユーザーがメールアドレスを確認した場合" do
      it "new_learning_customer_session_path へリダイレクトされる" do
        customer = build_unconfirmed_customer(domain_name: "learning")

        get customer_confirmation_path(confirmation_token: customer.confirmation_token)

        expect(response).to redirect_to(new_learning_customer_session_path)
      end
    end
  end
end
