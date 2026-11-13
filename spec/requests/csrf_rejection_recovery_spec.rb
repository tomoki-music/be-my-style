require "rails_helper"

# 「The change you wanted was rejected.」(public/422.html) は、CSRF 検証に失敗した送信で出る。
# 正規の利用者でも、開いたままの古い画面(別タブ・戻る操作・ブラウザの復元)から送信すると、
# ログイン・ログアウトでトークンが作り直された後なので失敗する。
# ここでは、保護(拒否)はそのままに、英語の画面ではなく開き直しの案内へ戻すことを確認する。
RSpec.describe "CSRF 検証に失敗した送信の扱い", type: :request do
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }

  let(:password) { "password123" }
  let(:customer) do
    FactoryBot.create(:customer, domain_name: "music", password: password, password_confirmation: password,
                                 confirmed_at: Time.current, onboarding_done: true)
  end
  let(:expired_message) { CsrfRejectionRecovery::EXPIRED_FORM_MESSAGE }
  let(:session_cookie_key) { Rails.application.config.session_options[:key] }

  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def form_token(action)
    doc.at_css(%(form[action="#{action}"] input[name="authenticity_token"]))["value"]
  end

  def meta_token
    doc.at_css('meta[name="csrf-token"]')["content"]
  end

  def login_form_token(path = new_customer_session_path, action = customer_session_path)
    get path
    form_token(action)
  end

  def post_login(token:, action: customer_session_path, headers: {})
    post action,
         params: { authenticity_token: token, customer: { email: customer.email, password: password, remember_me: "0" } },
         headers: headers
  end

  def signed_in?
    get public_notifications_path
    response.status == 200
  end

  describe "通常のログイン" do
    it "ログイン画面のトークンで送信すればログインできる(同じ Origin 付き)" do
      token = login_form_token

      post_login(token: token, headers: { "Origin" => "http://www.example.com" })

      expect(response).to have_http_status(:redirect)
      expect(response.location).not_to include("sign_in")
      expect(signed_in?).to eq true
    end

    it "Business のログイン画面からもログインできる" do
      token = login_form_token(new_business_customer_session_path, business_customer_session_path)

      post_login(token: token, action: business_customer_session_path)

      expect(response).to have_http_status(:redirect)
      expect(response.location).not_to include("sign_in")
      expect(signed_in?).to eq true
    end
  end

  describe "古い画面からの送信(報告された現象の再現)" do
    it "ログイン画面を開いたまま別のタブでログイン・ログアウトした後に送信すると、拒否して案内付きでログイン画面へ戻す" do
      stale_token = login_form_token

      # 別のタブ: 同じブラウザ(同じ Cookie)でログインしてログアウトする。セッションが作り直される。
      post_login(token: login_form_token)
      expect(signed_in?).to eq true
      delete destroy_customer_session_path, params: { authenticity_token: meta_token }

      post_login(token: stale_token, headers: { "Referer" => "http://www.example.com#{new_customer_session_path}" })

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(new_customer_session_path)
      follow_redirect!
      expect(response.body).to include(expired_message)
      expect(response.body).not_to include("The change you wanted was rejected")
      expect(signed_in?).to eq false
      expect(customer.reload.sign_in_count).to eq 1
    end

    it "ブラウザを閉じてセッションが消えた後に、復元された画面から送信しても実行しない" do
      stale_token = login_form_token
      cookies.delete(session_cookie_key)

      post_login(token: stale_token)

      expect(response).to have_http_status(:see_other)
      expect(signed_in?).to eq false
      expect(customer.reload.sign_in_count).to eq 0
    end

    it "ログイン後の画面に残った古いトークンでログアウトしても、ログアウトせず案内する(操作は再実行しない)" do
      post_login(token: login_form_token)
      get public_notifications_path
      stale_token = meta_token

      # 別のタブでログアウトして、もう一度ログインした(トークンが作り直された)。
      delete destroy_customer_session_path, params: { authenticity_token: stale_token }
      post_login(token: login_form_token)

      delete destroy_customer_session_path,
             params: { authenticity_token: stale_token },
             headers: { "Referer" => "http://www.example.com#{public_notifications_path}" }

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(public_notifications_path)
      expect(flash[:alert]).to eq expired_message
      expect(signed_in?).to eq true
    end
  end

  describe "不正な送信の拒否" do
    it "トークンが無い・偽物のログインは受け付けない" do
      get new_customer_session_path

      post_login(token: nil)
      expect(response).to have_http_status(:see_other)
      post_login(token: "forged-token")
      expect(response).to have_http_status(:see_other)

      expect(signed_in?).to eq false
      expect(customer.reload.sign_in_count).to eq 0
    end

    it "別サイトの Origin からの送信は、正しいトークンでも受け付けない" do
      allow(Rails.logger).to receive(:warn).and_call_original
      token = login_form_token

      post_login(token: token, headers: { "Origin" => "https://evil.example" })

      expect(response).to have_http_status(:see_other)
      expect(signed_in?).to eq false
      expect(Rails.logger).to have_received(:warn).with(/\[CSRF\] rejected reason=origin_mismatch .*path=\/customers\/sign_in/)
    end

    it "同じサイトの Referer はクエリ付きで戻すが、ログにはクエリを残さない" do
      allow(Rails.logger).to receive(:warn).and_call_original
      get new_customer_session_path

      post_login(token: "forged-token", headers: { "Referer" => "http://www.example.com/customers/password/edit?reset_password_token=secret-value" })

      expect(response).to redirect_to("/customers/password/edit?reset_password_token=secret-value")
      expect(Rails.logger).to have_received(:warn).with(
        a_string_matching(%r{referer=/customers/password/edit }).and(a_string_excluding("secret-value"))
      )
    end

    it "戻り先は同じサイトの Referer だけを使い、外部の Referer には戻さない" do
      get new_customer_session_path

      post_login(token: "forged-token", headers: { "Referer" => "https://evil.example/phish" })

      expect(response).to redirect_to(root_path)
    end

    it "Business の画面からの送信で Referer が無ければ Business のトップへ戻す" do
      get new_business_customer_session_path

      post_login(token: "forged-token", action: business_customer_session_path)

      expect(response).to redirect_to(business_root_path)
      expect(signed_in?).to eq false
    end

    it "JSON・Ajax の送信には 422 と日本語の案内を返す(画面遷移させない)" do
      get new_customer_session_path

      post customer_session_path,
           params: { authenticity_token: "forged-token", customer: { email: customer.email, password: password } },
           headers: { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to eq("error" => expired_message)
      expect(signed_in?).to eq false
    end

    it "拒否の理由をトークン・Cookie の値を含めずにログへ残す" do
      allow(Rails.logger).to receive(:warn).and_call_original
      stale_token = login_form_token
      cookies.delete(session_cookie_key)

      post_login(token: stale_token)

      expect(Rails.logger).to have_received(:warn).with(
        a_string_matching(/\[CSRF\] rejected reason=session_token_missing method=POST path=\/customers\/sign_in action=public\/sessions#create/)
          .and(a_string_excluding(stale_token))
          .and(a_string_excluding(password))
      )
    end
  end

  describe "ログイン画面のキャッシュ" do
    it "ログイン画面はブラウザに保存させず、Turbolinks の戻る操作でも古い画面を使わない" do
      [new_customer_session_path, new_business_customer_session_path].each do |path|
        get path

        expect(response.headers["Cache-Control"]).to include("no-store")
        expect(doc.at_css('meta[name="turbolinks-cache-control"]')["content"]).to eq "no-cache"
      end
    end

    it "ログイン後の通常の画面は従来どおり Turbolinks のキャッシュを使う" do
      post_login(token: login_form_token)
      get public_notifications_path

      expect(doc.at_css('meta[name="turbolinks-cache-control"]')).to be_nil
    end
  end

  describe "退会済みアカウント" do
    def expect_login_rejected
      expect(response.location.to_s).not_to eq(root_url) if response.redirect?
      expect(signed_in?).to eq false
    end

    it "退会処理の後は、ログイン中だったセッションも元のメールアドレス・パスワードも使えない" do
      original_email = customer.email
      post_login(token: login_form_token)
      expect(signed_in?).to eq true

      expect(Customers::Withdrawal::Execute.call(customer)).not_to be_blocked

      expect(signed_in?).to eq false

      post customer_session_path,
           params: { authenticity_token: login_form_token, customer: { email: original_email, password: password } }
      expect_login_rejected
    end

    it "退会済み(withdrawn_at あり)の会員は、正しいトークンとパスワードでもログインできない" do
      customer.update_columns(withdrawn_at: Time.current, is_deleted: true)

      post_login(token: login_form_token)

      expect_login_rejected
      expect(customer.reload.sign_in_count).to eq 0
    end

    it "ログイン中に退会済みになった会員の既存セッションは拒否される" do
      post_login(token: login_form_token)
      expect(signed_in?).to eq true

      customer.update_columns(withdrawn_at: Time.current, is_deleted: true)

      get public_notifications_path
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("sign_in")
    end
  end

  def a_string_excluding(text)
    satisfy { |value| !value.include?(text.to_s) }
  end
end
