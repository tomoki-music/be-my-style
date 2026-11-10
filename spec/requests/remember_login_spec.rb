require "rails_helper"

# ブラウザを閉じるとセッション Cookie は消え、remember_customer_token だけが残る。
# request spec ではセッション Cookie を消すことで、その状態を再現する。
RSpec.describe "ログインの30日保持", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }

  let(:session_cookie_key) { Rails.application.config.session_options[:key] }
  let(:password) { "password123" }

  def close_browser!
    cookies.delete(session_cookie_key)
  end

  shared_examples "30日間ログインを保持する" do
    def sign_in_from_form(remember: "1")
      post sign_in_path, params: { customer: { email: customer.email, password: password, remember_me: remember } }
      expect(response).to have_http_status(:redirect)
      expect(response.location).not_to include("sign_in")
    end

    it "ログイン画面のチェックは最初からオンになっている" do
      get new_sign_in_path

      checkbox = Nokogiri::HTML(response.body).at_css("input[type=checkbox][name='customer[remember_me]']")
      expect(checkbox["checked"]).to be_present
    end

    it "ブラウザを閉じて開き直しても、29日後まではログインしたまま" do
      sign_in_from_form
      expect(cookies["remember_customer_token"]).to be_present

      travel_to(29.days.from_now) do
        close_browser!
        get protected_path
        expect(response).to have_http_status(:ok)
      end
    end

    it "30日を過ぎると再ログインが必要になる(利用しても期限は延びない)" do
      sign_in_from_form

      travel_to(15.days.from_now) do
        close_browser!
        get protected_path
        expect(response).to have_http_status(:ok)
      end

      travel_to(31.days.from_now) do
        close_browser!
        get protected_path
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include("sign_in")
      end
    end

    it "ログアウトすると、保存していた Cookie を戻しても再ログインが必要になる" do
      sign_in_from_form
      saved_token = cookies["remember_customer_token"]

      delete destroy_customer_session_path
      expect(cookies["remember_customer_token"]).to be_blank

      close_browser!
      cookies["remember_customer_token"] = saved_token
      get protected_path
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("sign_in")
    end

    it "チェックを外してログインした場合は、ブラウザを閉じると再ログインが必要になる" do
      sign_in_from_form(remember: "0")
      expect(cookies["remember_customer_token"]).to be_blank

      close_browser!
      get protected_path
      expect(response).to have_http_status(:redirect)
    end
  end

  context "音楽" do
    let(:customer) do
      FactoryBot.create(:customer, domain_name: "music", password: password, password_confirmation: password,
                                   confirmed_at: Time.current, onboarding_done: true)
    end
    let(:sign_in_path) { customer_session_path }
    let(:new_sign_in_path) { new_customer_session_path }
    let(:protected_path) { public_notifications_path }

    include_examples "30日間ログインを保持する"
  end

  context "ビジネス" do
    let(:customer) do
      FactoryBot.create(:customer, domain_name: "business", password: password, password_confirmation: password,
                                   confirmed_at: Time.current, onboarding_done: true)
    end
    let(:sign_in_path) { business_customer_session_path }
    let(:new_sign_in_path) { new_business_customer_session_path }
    let(:protected_path) { business_notifications_path }

    include_examples "30日間ログインを保持する"
  end
end
