require 'rails_helper'

RSpec.describe "Singing::Checkout", type: :request do
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  let(:free_customer) { create(:customer, domain_name: "singing") }
  let(:paid_customer) do
    create(:customer, domain_name: "singing").tap do |c|
      create(:subscription, customer: c,
             stripe_customer_id: "cus_existing",
             stripe_subscription_id: "sub_existing",
             status: "active", plan: "light")
    end
  end

  let(:test_price_id) { "price_test_light_xxx" }
  let(:session_id)    { "cs_test_session_001" }

  # Stripe::StripeObject は動的オブジェクトのため double で扱う
  let(:stripe_checkout_session) do
    double("Stripe::Checkout::Session",
      id:                session_id,
      url:               "https://checkout.stripe.com/pay/xxx",
      customer:          "cus_new_001",
      subscription:      "sub_new_001",
      customer_details:  double("customer_details", email: free_customer.email),
      metadata:          double("metadata", "[]" => "light"),
      line_items:        double("line_items",
        data: [double("line_item",
          price: double("price", id: test_price_id))])
    )
  end

  before do
    CustomerDomain.find_or_create_by!(customer: free_customer, domain: singing_domain)

    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:stripe, :price).and_return(
      {
        light:   { test: test_price_id,       live: "price_live_light" },
        core:    { test: "price_test_core",    live: "price_live_core" },
        premium: { test: "price_test_premium", live: "price_live_premium" }
      }
    )
    allow(Rails.application.credentials).to receive(:dig).with(:singing_lp_cancel_url)
      .and_return("https://example.com/lp")
  end

  # =========================================================
  # GET /singing/checkout/:plan
  # =========================================================
  describe "GET /singing/checkout/:plan (redirect)" do
    context "有効なプラン (light) の場合" do
      before do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(stripe_checkout_session)
      end

      it "Stripe Checkout URL へリダイレクトする" do
        get singing_lp_checkout_path("light")
        expect(response).to redirect_to("https://checkout.stripe.com/pay/xxx")
      end
    end

    context "ルート制約により free プランはマッチしない" do
      it "ActionController::RoutingError が発生する" do
        expect { get "/singing/checkout/free" }.to raise_error(ActionController::RoutingError)
      end
    end

    context "既存有料ユーザーが別プランの Checkout へアクセスした場合" do
      let(:portal_session) do
        double("Stripe::BillingPortal::Session", url: "https://billing.stripe.com/portal/xxx")
      end

      before do
        CustomerDomain.find_or_create_by!(customer: paid_customer, domain: singing_domain)
        sign_in paid_customer
        allow(Stripe::BillingPortal::Session).to receive(:create).and_return(portal_session)
      end

      it "Checkout Session を新規作成しない" do
        expect(Stripe::Checkout::Session).not_to receive(:create)
        get singing_lp_checkout_path("core")
      end

      it "Stripe Portal へリダイレクトする" do
        get singing_lp_checkout_path("core")
        expect(response).to redirect_to("https://billing.stripe.com/portal/xxx")
      end

      it "Subscription レコードが増えない" do
        expect {
          get singing_lp_checkout_path("core")
        }.not_to change(Subscription, :count)
      end
    end
  end

  # =========================================================
  # GET /singing/checkout/success
  # =========================================================
  describe "GET /singing/checkout/success" do
    before do
      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(stripe_checkout_session)
    end

    context "ログイン済みユーザーの場合" do
      before { sign_in free_customer }

      it "サブスクリプションが作成される" do
        expect {
          get singing_checkout_success_path, params: { session_id: session_id }
        }.to change(Subscription, :count).by(1)
      end

      it "同じ session_id を 2 回処理しても重複しない" do
        expect {
          get singing_checkout_success_path, params: { session_id: session_id }
          get singing_checkout_success_path, params: { session_id: session_id }
        }.to change(Subscription, :count).by(1)
      end

      it "2 回目以降も plan が正しいまま保たれる" do
        2.times { get singing_checkout_success_path, params: { session_id: session_id } }
        expect(free_customer.reload.plan).to eq("light")
      end

      it "singing_root_path へリダイレクトする" do
        get singing_checkout_success_path, params: { session_id: session_id }
        expect(response).to redirect_to(singing_root_path)
      end

      it "PendingStripeCheckout は作成されない" do
        expect {
          get singing_checkout_success_path, params: { session_id: session_id }
        }.not_to change(PendingStripeCheckout, :count)
      end
    end

    context "未ログインユーザーの場合" do
      it "登録画面へ誘導する" do
        get singing_checkout_success_path, params: { session_id: session_id }
        expect(response).to redirect_to(new_singing_customer_registration_path)
      end

      it "サブスクリプションは即座に作成されない" do
        expect {
          get singing_checkout_success_path, params: { session_id: session_id }
        }.not_to change(Subscription, :count)
      end

      it "PendingStripeCheckout が DB に保存される" do
        expect {
          get singing_checkout_success_path, params: { session_id: session_id }
        }.to change(PendingStripeCheckout, :count).by(1)
      end

      it "PendingStripeCheckout に正しい情報が保存される" do
        get singing_checkout_success_path, params: { session_id: session_id }
        pending = PendingStripeCheckout.find_by!(stripe_session_id: session_id)
        expect(pending.stripe_email).to eq(free_customer.email)
        expect(pending.stripe_customer_id).to eq("cus_new_001")
        expect(pending.stripe_subscription_id).to eq("sub_new_001")
        expect(pending.plan_key).to eq("light")
        expect(pending.processed_at).to be_nil
      end

      it "同じ session_id を 2 回ヒットしても PendingStripeCheckout は 1 件のみ" do
        expect {
          get singing_checkout_success_path, params: { session_id: session_id }
          get singing_checkout_success_path, params: { session_id: session_id }
        }.to change(PendingStripeCheckout, :count).by(1)
      end
    end
  end

  # =========================================================
  # Webhook と success_url の連続処理でも重複しない
  # =========================================================
  describe "sync_subscription_from_checkout_session! の冪等性" do
    let(:concern_host) do
      Class.new do
        include StripeSubscriptionSync
        public :sync_subscription_from_checkout_session!
      end.new
    end

    before do
      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(stripe_checkout_session)
    end

    it "同じ session_id を 2 回 sync しても Subscription レコードは 1 件のみ" do
      expect {
        concern_host.sync_subscription_from_checkout_session!(free_customer, session_id)
        concern_host.sync_subscription_from_checkout_session!(free_customer, session_id)
      }.to change(Subscription, :count).by(1)
    end

    it "plan が light に正しく設定される" do
      concern_host.sync_subscription_from_checkout_session!(free_customer, session_id)
      expect(free_customer.reload.plan).to eq("light")
    end
  end

  # =========================================================
  # メール不一致: 別顧客への誤紐付け防止（クロス汚染保護）
  # =========================================================
  describe "別顧客の stripe_subscription_id による誤紐付け防止" do
    let(:customer_a) { create(:customer, domain_name: "singing", email: "payer@example.com") }
    let(:customer_b) { create(:customer, domain_name: "singing", email: "registrant@example.com") }

    let(:stripe_session_for_a) do
      double("Stripe::Checkout::Session",
        id:               session_id,
        customer:         "cus_payer",
        subscription:     "sub_cross_001",
        customer_details: double("customer_details", email: "payer@example.com"),
        metadata:         double("metadata", "[]" => "light"),
        line_items:       double("line_items",
          data: [double("line_item",
            price: double("price", id: test_price_id))])
      )
    end

    let(:concern_host) do
      Class.new do
        include StripeSubscriptionSync
        public :sync_subscription_from_checkout_session!
      end.new
    end

    before do
      CustomerDomain.find_or_create_by!(customer: customer_a, domain: singing_domain)
      CustomerDomain.find_or_create_by!(customer: customer_b, domain: singing_domain)
      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(stripe_session_for_a)
    end

    it "先に紐付けた customer_a にはサブスクが設定される" do
      concern_host.sync_subscription_from_checkout_session!(customer_a, session_id)
      expect(customer_a.reload.plan).to eq("light")
    end

    it "同じ subscription_id を customer_b に紐付けようとしても false が返る" do
      concern_host.sync_subscription_from_checkout_session!(customer_a, session_id)
      result = concern_host.sync_subscription_from_checkout_session!(customer_b, session_id)
      expect(result).to be_falsy
    end

    it "customer_b のプランは free のまま変わらない" do
      concern_host.sync_subscription_from_checkout_session!(customer_a, session_id)
      concern_host.sync_subscription_from_checkout_session!(customer_b, session_id)
      expect(customer_b.reload.plan).to eq("free")
    end
  end

  # =========================================================
  # Registrations: メール不一致のとき自動紐付けをスキップ＆flash表示
  # =========================================================
  describe "Singing::RegistrationsController — メール不一致による紐付けスキップ" do
    let(:stripe_email_for_match)    { "matchuser@example.com" }
    let(:stripe_email_for_mismatch) { "payer@example.com" }
    let(:register_email_mismatch)   { "registrant@example.com" }

    let(:stripe_session_match) do
      double("Stripe::Checkout::Session",
        id:               session_id,
        customer:         "cus_match",
        subscription:     "sub_match_001",
        customer_details: double("customer_details", email: stripe_email_for_match),
        metadata:         double("metadata", "[]" => "light"),
        line_items:       double("line_items",
          data: [double("line_item",
            price: double("price", id: test_price_id))])
      )
    end

    let(:stripe_session_mismatch) do
      double("Stripe::Checkout::Session",
        id:               session_id,
        customer:         "cus_payer",
        subscription:     "sub_mismatch_001",
        customer_details: double("customer_details", email: stripe_email_for_mismatch),
        metadata:         double("metadata", "[]" => "light"),
        line_items:       double("line_items",
          data: [double("line_item",
            price: double("price", id: test_price_id))])
      )
    end

    def post_singing_registration(email)
      post singing_customer_registration_path, params: {
        customer: {
          email:                 email,
          password:              "password",
          password_confirmation: "password",
          name:                  "test user"
        }
      }
    end

    # Deviseの:confirmableにより新規登録直後はactive_for_authentication?がfalseになるため
    # after_sign_up_path_forが呼ばれるよう confirmed? の状態をモックしてテストする
    context "Stripeメールと登録メールが一致する場合" do
      before do
        allow_any_instance_of(Customer).to receive(:active_for_authentication?).and_return(true)
        allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(stripe_session_match)
        # checkout success を経由して session[:pending_stripe_session_id] をセット
        get singing_checkout_success_path, params: { session_id: session_id }
      end

      it "subscriptionが作成される" do
        expect { post_singing_registration(stripe_email_for_match) }.to change(Subscription, :count).by(1)
      end

      it "flash[:alert]は設定されない" do
        post_singing_registration(stripe_email_for_match)
        expect(flash[:alert]).to be_nil
      end

      it "PendingStripeCheckout の processed_at が設定される" do
        post_singing_registration(stripe_email_for_match)
        pending = PendingStripeCheckout.find_by(stripe_session_id: session_id)
        expect(pending&.processed_at).not_to be_nil
      end
    end

    context "Stripeメールと登録メールが不一致の場合" do
      before do
        allow_any_instance_of(Customer).to receive(:active_for_authentication?).and_return(true)
        allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(stripe_session_mismatch)
        # checkout success を経由して session[:pending_stripe_session_id] をセット
        get singing_checkout_success_path, params: { session_id: session_id }
      end

      it "subscriptionは作成されない" do
        expect { post_singing_registration(register_email_mismatch) }.not_to change(Subscription, :count)
      end

      it "flash[:alert]にお問い合わせ案内が設定される" do
        post_singing_registration(register_email_mismatch)
        expect(flash[:alert]).to include("決済時のメールアドレス")
        expect(flash[:alert]).to include("i.tomoki0218@gmail.com")
      end

      it "pending_stripe_session_idが削除される" do
        post_singing_registration(register_email_mismatch)
        expect(session[:pending_stripe_session_id]).to be_nil
      end

      it "Railsログに警告が出力される" do
        expect(Rails.logger).to receive(:warn).with(/Stripe email mismatch/)
        post_singing_registration(register_email_mismatch)
      end
    end
  end

  # =========================================================
  # Confirmable 環境: after_inactive_sign_up_path_for での customer 紐付け
  # =========================================================
  describe "Singing::RegistrationsController — Confirmable inactive signup での customer 紐付け" do
    let(:register_email)       { "confirmable_user@example.com" }
    let(:inactive_session_id)  { "cs_inactive_test_001" }

    let(:stripe_session_for_inactive) do
      double("Stripe::Checkout::Session",
        id:               inactive_session_id,
        customer:         "cus_inactive_001",
        subscription:     "sub_inactive_001",
        customer_details: double("customer_details", email: register_email),
        metadata:         double("metadata", "[]" => "light"),
        line_items:       double("line_items",
          data: [double("line_item",
            price: double("price", id: test_price_id))])
      )
    end

    before do
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .and_return(stripe_session_for_inactive)
      # checkout/success 経由で session と DB の両方をセット
      get singing_checkout_success_path, params: { session_id: inactive_session_id }
    end

    def post_singing_registration(email)
      post singing_customer_registration_path, params: {
        customer: {
          email:                 email,
          password:              "password",
          password_confirmation: "password",
          name:                  "test user"
        }
      }
    end

    context "stripe_email と登録メールが一致する場合" do
      it "PendingStripeCheckout に customer が紐付けられる" do
        post_singing_registration(register_email)
        pending = PendingStripeCheckout.find_by!(stripe_session_id: inactive_session_id)
        expect(pending.customer).not_to be_nil
        expect(pending.customer.email).to eq(register_email)
      end

      it "processed_at は未設定のまま（ログイン時に同期するため）" do
        post_singing_registration(register_email)
        pending = PendingStripeCheckout.find_by!(stripe_session_id: inactive_session_id)
        expect(pending.processed_at).to be_nil
      end

      it "Subscription はまだ作成されない" do
        expect { post_singing_registration(register_email) }.not_to change(Subscription, :count)
      end

      it "flash[:alert] は設定されない" do
        post_singing_registration(register_email)
        expect(flash[:alert]).to be_nil
      end
    end

    context "stripe_email と登録メールが不一致の場合" do
      let(:mismatch_email) { "other_user@example.com" }

      it "PendingStripeCheckout に customer は紐付けられない" do
        post_singing_registration(mismatch_email)
        pending = PendingStripeCheckout.find_by!(stripe_session_id: inactive_session_id)
        expect(pending.customer).to be_nil
      end

      it "flash[:alert] にお問い合わせ案内が設定される" do
        post_singing_registration(mismatch_email)
        expect(flash[:alert]).to include("決済時のメールアドレス")
        expect(flash[:alert]).to include("i.tomoki0218@gmail.com")
      end
    end
  end

  # =========================================================
  # 初回ログイン: after_sign_in_path_for での自動同期
  # =========================================================
  describe "Singing::SessionsController — 初回ログイン時の自動同期" do
    let(:customer_email)    { "login_sync_user@example.com" }
    let(:login_session_id)  { "cs_login_sync_001" }
    let(:confirmed_customer) do
      create(:customer, domain_name: "singing", email: customer_email)
    end

    let(:stripe_session_for_login) do
      double("Stripe::Checkout::Session",
        id:               login_session_id,
        customer:         "cus_login_001",
        subscription:     "sub_login_001",
        customer_details: double("customer_details", email: customer_email),
        metadata:         double("metadata", "[]" => "light"),
        line_items:       double("line_items",
          data: [double("line_item",
            price: double("price", id: test_price_id))])
      )
    end

    before do
      CustomerDomain.find_or_create_by!(customer: confirmed_customer, domain: singing_domain)
      allow(Stripe::Checkout::Session).to receive(:retrieve)
        .and_return(stripe_session_for_login)
    end

    def post_singing_session(email = customer_email)
      post singing_customer_session_path, params: {
        customer: { email: email, password: "password" }
      }
    end

    context "stripe_email が一致する未処理 PendingStripeCheckout がある場合" do
      let!(:pending) do
        create(:pending_stripe_checkout,
          stripe_session_id:      login_session_id,
          stripe_email:           customer_email,
          stripe_customer_id:     "cus_login_001",
          stripe_subscription_id: "sub_login_001",
          plan_key:               "light"
        )
      end

      it "サブスクリプションが同期される" do
        expect { post_singing_session }.to change(Subscription, :count).by(1)
      end

      it "PendingStripeCheckout の processed_at が設定される" do
        post_singing_session
        expect(pending.reload.processed_at).not_to be_nil
      end

      it "PendingStripeCheckout に customer が紐付けられる" do
        post_singing_session
        expect(pending.reload.customer).to eq(confirmed_customer)
      end

      it "flash[:notice] にプラン反映メッセージが設定される" do
        post_singing_session
        expect(flash[:notice]).to include("プラン登録が完了しました")
      end
    end

    context "customer_id で紐付け済みの PendingStripeCheckout がある場合（Confirmable 経由）" do
      let!(:pending) do
        create(:pending_stripe_checkout,
          stripe_session_id:      login_session_id,
          stripe_email:           customer_email,
          stripe_customer_id:     "cus_login_001",
          stripe_subscription_id: "sub_login_001",
          plan_key:               "light",
          customer:               confirmed_customer
        )
      end

      it "サブスクリプションが同期される" do
        expect { post_singing_session }.to change(Subscription, :count).by(1)
      end

      it "PendingStripeCheckout の processed_at が設定される" do
        post_singing_session
        expect(pending.reload.processed_at).not_to be_nil
      end
    end

    context "未処理の PendingStripeCheckout が存在しない場合" do
      it "サブスクリプションは作成されない" do
        expect { post_singing_session }.not_to change(Subscription, :count)
      end
    end

    context "processed_at 設定済みの PendingStripeCheckout のみ存在する場合（二重同期防止）" do
      let!(:processed_pending) do
        create(:pending_stripe_checkout,
          stripe_session_id:      login_session_id,
          stripe_email:           customer_email,
          stripe_customer_id:     "cus_login_001",
          stripe_subscription_id: "sub_login_001",
          plan_key:               "light",
          customer:               confirmed_customer,
          processed_at:           1.hour.ago
        )
      end

      it "サブスクリプションは再作成されない" do
        expect { post_singing_session }.not_to change(Subscription, :count)
      end

      it "processed_at の値は変わらない" do
        original_processed_at = processed_pending.processed_at
        post_singing_session
        expect(processed_pending.reload.processed_at).to be_within(1.second).of(original_processed_at)
      end
    end
  end
end
