require "rails_helper"

# Business の利用者が、音楽側の登録を求める案内(「音楽プラットフォームの利用には…」)を経由せずにログインできること。
# 音楽・歌声側のログイン後の行き先は変えない。
RSpec.describe "Business ログインの案内と行き先", type: :request do
  MUSIC_ONLY_NOTICE = "音楽プラットフォームの利用には音楽ドメインの登録が必要です。".freeze

  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:singing_domain) { Domain.find_or_create_by!(name: "singing") }

  let(:business_only) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:both) do
    create(:customer, domain_name: "music", onboarding_done: true).tap do |customer|
      CustomerDomain.create!(customer: customer, domain: business_domain)
    end
  end
  let(:music_only) { create(:customer, domain_name: "music", onboarding_done: true) }

  def sign_in_via(path, customer, password: "password")
    post path, params: { customer: { email: customer.email, password: password } }
  end

  # リダイレクトをたどり、途中で出たフラッシュをすべて集める。
  def follow_and_collect_flash
    messages = flash.to_hash.values
    5.times do
      break unless response.redirect?

      follow_redirect!
      messages.concat(flash.to_hash.values)
    end
    messages
  end

  describe "Business のログイン画面(/business/sign_in)" do
    it "Business だけの利用者は、音楽側の登録を求められずに Business ホームへ進む" do
      sign_in_via(business_customer_session_path, business_only)

      expect(response).to redirect_to(business_root_path)
      expect(follow_and_collect_flash).not_to include(MUSIC_ONLY_NOTICE)
      expect(response.body).not_to include("音楽プラットフォーム")
    end

    it "音楽と Business の両方の利用者も Business ホームへ進む" do
      sign_in_via(business_customer_session_path, both)

      expect(response).to redirect_to(business_root_path)
    end

    it "Business 未登録の人には Business の利用開始を案内する" do
      sign_in_via(business_customer_session_path, music_only)

      expect(response).to redirect_to(business_join_path)
      follow_redirect!
      expect(response.body).to include("Businessドメインの利用を開始しますか？")
      expect(response.body).not_to include("音楽プラットフォーム")
    end

    it "パスワード違いは Business のログイン画面のまま原因を出す" do
      sign_in_via(business_customer_session_path, business_only, password: "wrong-password")

      expect(response.body).to include("NAKAMA ビジネスコミュニティへようこそ")
      expect(response.body).to include("メールアドレスまたはパスワードが違います。")
    end

    it "メール未確認は Business のログイン画面へ戻し、本人確認が必要と案内する(ログインはさせない)" do
      unconfirmed = create(:customer, domain_name: "business", confirmed_at: nil)

      sign_in_via(business_customer_session_path, unconfirmed)

      expect(response).to redirect_to(new_business_customer_session_url)
      expect(flash[:alert]).to eq "メールアドレスの本人確認が必要です。"
      get business_projects_path
      expect(response).to redirect_to(new_business_customer_session_url)
    end

    it "退会済みは Business のログイン画面へ戻し、退会済みと案内する(ログインはさせない)" do
      withdrawn = create(:customer, domain_name: "business", is_deleted: true)

      sign_in_via(business_customer_session_path, withdrawn)

      expect(response).to redirect_to(new_business_customer_session_url)
      expect(flash[:alert]).to eq "このアカウントは退会済みです。"
    end
  end

  describe "未ログインで Business の画面を開いたとき" do
    it "音楽のログイン画面ではなく Business のログイン画面へ案内し、ログイン後は開こうとした画面へ戻す" do
      get business_projects_path

      expect(response).to redirect_to(new_business_customer_session_url)

      sign_in_via(business_customer_session_path, business_only)
      expect(response).to redirect_to(business_projects_path)
    end

    it "Business 未登録の人は保存された戻り先があっても利用開始画面へ進む(制限を回避できない)" do
      get business_projects_path
      sign_in_via(business_customer_session_path, music_only)

      expect(response).to redirect_to(business_join_path)
    end

    it "メール未確認・退会済みは保存された戻り先があってもログインできない" do
      unconfirmed = create(:customer, domain_name: "business", confirmed_at: nil)
      withdrawn = create(:customer, domain_name: "business", is_deleted: true)

      [unconfirmed, withdrawn].each do |customer|
        get business_projects_path
        sign_in_via(business_customer_session_path, customer)
        expect(response).to redirect_to(new_business_customer_session_url)
        get business_projects_path
        expect(response).to redirect_to(new_business_customer_session_url)
      end
    end

    it "利用開始画面などログイン系の画面へは戻さない(ループしない)" do
      get business_join_path
      expect(response).to redirect_to(new_business_customer_session_path)

      sign_in_via(business_customer_session_path, business_only)
      expect(response).to redirect_to(business_root_path)
    end

    it "保存された戻り先は音楽・歌声でログインしたときに破棄され、後のログインに残らない" do
      singing_and_business = create(:customer, domain_name: "singing", onboarding_done: true)
      CustomerDomain.create!(customer: singing_and_business, domain: business_domain)

      get business_projects_path
      sign_in_via(customer_session_path, both)
      expect(response).to redirect_to(root_path)
      expect(session["customer_return_to"]).to be_nil

      delete destroy_customer_session_path
      get business_projects_path
      sign_in_via(singing_customer_session_path, singing_and_business)
      expect(response).to redirect_to(singing_root_path)
      expect(session["customer_return_to"]).to be_nil
    end
  end

  describe "ログイン後に戻す画面の判定" do
    def restorable?(path)
      Public::SessionsController.new.send(:restorable_business_path?, path)
    end

    it "アプリ内の Business の画面だけを戻り先にする" do
      expect(restorable?("/business/projects/1")).to eq true
      expect(restorable?("/business?community_page=2")).to eq true
      expect(restorable?("/business")).to eq true
    end

    it "外部 URL・Business 以外・ログイン系の画面は戻り先にしない" do
      [
        "https://evil.example.com/business/projects",
        "//evil.example.com/business",
        "/business//evil.example.com",
        "/business/\\evil.example.com",
        "/businessx",
        "/public/communities",
        "/singing",
        "/business/sign_in",
        "/business/sign_up?x=1",
        "/business/password/new",
        "/business/join",
        ""
      ].each do |path|
        expect(restorable?(path)).to eq(false), path
      end
    end
  end

  describe "音楽のログイン画面(/customers/sign_in)から入った場合" do
    it "Business だけの利用者は音楽トップを経由せず Business ホームへ進み、音楽向けの案内が出ない" do
      sign_in_via(customer_session_path, business_only)

      expect(response).to redirect_to(business_root_path)
      expect(follow_and_collect_flash).not_to include(MUSIC_ONLY_NOTICE)
    end

    it "音楽の利用者は従来どおり音楽トップへ進む" do
      sign_in_via(customer_session_path, both)

      expect(response).to redirect_to(root_path)
    end

    it "歌声だけの利用者の行き先は変えない(音楽トップから歌声へ移る従来の動き)" do
      singing_only = create(:customer, domain_name: "singing", onboarding_done: true)

      sign_in_via(customer_session_path, singing_only)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response).to redirect_to(singing_root_path)
    end

    it "音楽の画面を未ログインで開いたときの戻り先は音楽のログイン画面のまま" do
      get public_communities_path

      expect(response).to redirect_to(new_customer_session_url)
    end
  end

  describe "パスワード再設定の後" do
    def reset_password_for(customer)
      token = customer.send_reset_password_instructions
      put customer_password_path, params: {
        customer: { reset_password_token: token, password: "new-password", password_confirmation: "new-password" }
      }
    end

    it "Business だけの利用者は Business ホームへ戻る" do
      reset_password_for(business_only)

      expect(response).to redirect_to(business_root_path)
      expect(follow_and_collect_flash).not_to include(MUSIC_ONLY_NOTICE)
    end

    it "音楽の利用者は従来どおり音楽トップへ戻る" do
      reset_password_for(both)

      expect(response).to redirect_to(public_homes_top_path)
    end

    it "歌声の利用者は音楽トップを経由せず歌声へ戻る(Business と両方でも歌声が優先)" do
      singing_and_business = create(:customer, domain_name: "singing", onboarding_done: true)
      CustomerDomain.create!(customer: singing_and_business, domain: business_domain)

      reset_password_for(singing_and_business)

      expect(response).to redirect_to(singing_root_path)
      expect(follow_and_collect_flash).not_to include(MUSIC_ONLY_NOTICE)
    end
  end

  describe "ログアウト" do
    it "Business の画面からのログアウト後は Business のログイン画面へ戻り、音楽向けの案内は出ない" do
      sign_in business_only

      delete destroy_customer_session_path, headers: { "HTTP_REFERER" => "http://www.example.com#{business_root_path}" }

      expect(response).to redirect_to(new_business_customer_session_path)
      expect(follow_and_collect_flash).not_to include(MUSIC_ONLY_NOTICE)
    end
  end
end
