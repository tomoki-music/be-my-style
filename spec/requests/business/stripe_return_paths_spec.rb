require "rails_helper"

# 決済・キャンセル・ポータルの戻り先とエラー時の案内先(Stripe への通信は行わず、呼び出しを差し替える)。
RSpec.describe "Business の契約関連の戻り先", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:customer) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:plan_management) { edit_business_customer_path(customer, anchor: "plan-management") }

  before { sign_in customer }

  it "同期に成功したら契約プラン管理へ戻り、完了メッセージを表示する" do
    allow_any_instance_of(Business::StripeController).to receive(:sync_subscription_from_checkout_session!).and_return(true)

    get business_success_stripe_path(session_id: "cs_test_123")

    expect(response).to redirect_to(plan_management)
    expect(flash[:notice]).to eq "プラン登録が完了しました。"
    follow_redirect!
    expect(response.body).to include("プラン登録が完了しました。")
    expect(Nokogiri::HTML(response.body).at_css("#plan-management")).to be_present
  end

  it "反映を確認できない場合も契約プラン管理へ戻し、案内を表示する" do
    allow_any_instance_of(Business::StripeController).to receive(:sync_subscription_from_checkout_session!).and_return(false)

    get business_success_stripe_path(session_id: "cs_test_123")

    expect(response).to redirect_to(plan_management)
    expect(flash[:alert]).to eq "プランの反映を確認できませんでした。しばらくしてから再度ご確認ください。"
  end

  it "Stripe 側のエラーでも契約プラン管理へ戻す" do
    allow_any_instance_of(Business::StripeController).to receive(:sync_subscription_from_checkout_session!)
      .and_raise(Stripe::InvalidRequestError.new("No such session", "session_id"))

    get business_success_stripe_path(session_id: "cs_test_bad")

    expect(response).to redirect_to(plan_management)
    expect(flash[:alert]).to eq "プラン反映時にエラーが発生しました。"
  end

  it "契約済みでセッション ID が置換されていない場合も完了メッセージ付きで契約プラン管理へ戻す" do
    create(:subscription, customer: customer, plan: "core")

    get business_success_stripe_path(session_id: "{CHECKOUT_SESSION_ID}")

    expect(response).to redirect_to(plan_management)
    expect(flash[:notice]).to eq "プラン登録が完了しました。"
  end

  describe "決済の開始(create_checkout)" do
    it "Checkout のキャンセル時は契約プラン管理へ戻す(決済内容は変えない)" do
      allow_any_instance_of(Business::StripeController).to receive(:stripe_price_id_for).with("core").and_return("price_test_core")
      created = nil
      allow(Stripe::Checkout::Session).to receive(:create) do |args|
        created = args
        double(url: "https://checkout.stripe.test/session")
      end

      post business_checkout_path("core")

      expect(response).to redirect_to("https://checkout.stripe.test/session")
      expect(created[:cancel_url]).to eq edit_business_customer_url(customer, canceled: true)
      expect(created[:success_url]).to eq "#{business_success_stripe_url}?session_id={CHECKOUT_SESSION_ID}"
      expect(created[:line_items]).to eq [{ price: "price_test_core", quantity: 1 }]
      expect(created[:mode]).to eq "subscription"
    end

    it "プランが見つからない場合は契約プラン管理へ戻し、メッセージは変えない" do
      allow_any_instance_of(Business::StripeController).to receive(:stripe_price_id_for).and_return(nil)
      expect(Stripe::Checkout::Session).not_to receive(:create)

      post business_checkout_path("unknown")

      expect(response).to redirect_to(plan_management)
      expect(flash[:alert]).to eq "選択したプランが見つかりません。"
    end
  end

  describe "Stripe ポータル(portal)" do
    it "契約中なら return_url を契約プラン管理にしてポータルへ送る" do
      subscription = create(:subscription, customer: customer, plan: "core")
      created = nil
      allow(Stripe::BillingPortal::Session).to receive(:create) do |args|
        created = args
        double(url: "https://billing.stripe.test/portal")
      end

      post business_portal_path

      expect(response).to redirect_to("https://billing.stripe.test/portal")
      expect(created).to eq(customer: subscription.stripe_customer_id, return_url: edit_business_customer_url(customer))
    end

    it "Stripe 連携された契約が無い場合は契約プラン管理へ戻し、メッセージは変えない" do
      expect(Stripe::BillingPortal::Session).not_to receive(:create)

      post business_portal_path

      expect(response).to redirect_to(plan_management)
      expect(flash[:alert]).to eq "Stripe連携されたサブスクが見つかりません。もう一度プラン登録をお試しください。"
    end
  end

  it "未ログインでは契約関連の操作はログイン画面へ戻す" do
    sign_out customer

    post business_portal_path

    expect(response).to redirect_to(new_business_customer_session_path)
  end
end
