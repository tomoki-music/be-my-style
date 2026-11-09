require "rails_helper"

# 招待用URL(コミュニティ・プロジェクトの詳細画面のURL)を未ログインで開いて新規登録した人を、
# 確認メール → オンボーディング完了の後に、その詳細画面へ案内する。
RSpec.describe "Business 招待用URLからの新規登録", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:owner) { create(:customer, domain_name: "business", name: "運営者", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "招待テストコミュニティ") }
  let(:project) { Project.create!(community: community, customer: owner, title: "招待テスト企画", description: "説明") }

  before { CommunityCustomer.create!(community: community, customer: owner) }

  def register(email)
    post business_customer_registration_path, params: {
      customer: { email: email, password: "password", password_confirmation: "password", name: "新しい人" }
    }
    expect(response).to redirect_to(new_business_customer_session_path)
    Customer.find_by!(email: email)
  end

  def go_through_onboarding(client = self)
    client.get onboarding_step1_path
    client.get onboarding_step2_path
    client.get onboarding_step3_path
    client.patch onboarding_complete_path
  end

  # redirect_to マッチャは既定のセッションの応答を見るため、別のセッション(別ブラウザ)は Location のパスで比べる。
  def redirected_path(client)
    expect(client.response).to have_http_status(:found)
    URI.parse(client.response.location).path
  end

  def sign_in_via_form(client, customer)
    client.post business_customer_session_path, params: { customer: { email: customer.email, password: "password" } }
  end

  describe "コミュニティの招待" do
    it "未ログインで開いて登録 → 確認 → オンボーディング完了で、コミュニティの詳細画面に着く" do
      get business_community_path(community)
      expect(response).to redirect_to(new_business_customer_session_url)

      newcomer = register("community-invite@example.com")
      expect(newcomer.business_signup_invitation).to have_attributes(target_type: "Community", target_id: community.id)

      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      expect(response).to redirect_to(onboarding_step1_path)

      go_through_onboarding
      expect(response).to redirect_to(business_community_path(community))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("招待テストコミュニティ", "参加を申請する")

      # 着いたら招待先は消費され、参加・申請は起きていない。
      expect(BusinessSignupInvitation.exists?(customer_id: newcomer.id)).to be false
      expect(Permit.exists?(customer: newcomer)).to be false
    end

    it "次回の通常ログインでは招待先へ転送しない" do
      get business_community_path(community)
      newcomer = register("login-again@example.com")
      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      go_through_onboarding
      expect(response).to redirect_to(business_community_path(community))

      delete destroy_customer_session_path
      sign_in_via_form(self, newcomer)
      expect(response).to redirect_to(business_root_path)
    end

    it "オンボーディングを投稿で終えた場合も、投稿後に招待先へ案内する" do
      get business_community_path(community)
      newcomer = register("post-onboarding@example.com")
      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      get onboarding_step3_path

      post business_posts_path, params: { post: { title: "はじめまして", body: "よろしくお願いします", tag_list: "" } }
      expect(response).to redirect_to(business_community_path(community))
      expect(newcomer.reload.onboarding_done).to be true
      expect(BusinessSignupInvitation.exists?(customer_id: newcomer.id)).to be false
    end
  end

  describe "プロジェクトの招待" do
    it "確認メールを別のブラウザで開いても引き継ぎ、オンボーディング完了でプロジェクトの詳細画面へ転送する" do
      get business_project_path(project)
      newcomer = register("project-invite@example.com")
      expect(newcomer.business_signup_invitation).to have_attributes(target_type: "Project", target_id: project.id)

      # LINE 内ブラウザで招待URLを開き、確認メールは Safari で開く、など(Cookie を持たない別のセッション)。
      other_browser = open_session
      other_browser.get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      expect(redirected_path(other_browser)).to eq onboarding_step1_path

      go_through_onboarding(other_browser)
      expect(redirected_path(other_browser)).to eq business_project_path(project)

      # 閲覧権限は従来どおり: 親コミュニティ未参加なら、プロジェクトからコミュニティの参加案内へ移る。
      other_browser.follow_redirect!
      expect(redirected_path(other_browser)).to eq business_community_path(community)
    end

    it "オンボーディング中にコミュニティへ参加していれば、プロジェクトの詳細画面がそのまま開く" do
      community.update!(join_approval_mode: :auto)
      get business_project_path(project)
      newcomer = register("project-joined@example.com")
      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)

      get onboarding_step2_path
      post business_community_permit_path(community)
      expect(response).to redirect_to(onboarding_step2_path)
      get onboarding_step3_path
      patch onboarding_complete_path

      expect(response).to redirect_to(business_project_path(project))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("招待テスト企画")
    end

    it "元のブラウザに戻ってログインした場合も、オンボーディング後にプロジェクトへ案内する" do
      get business_project_path(project)
      newcomer = register("same-browser-login@example.com")
      newcomer.confirm

      sign_in_via_form(self, newcomer)
      expect(response).to redirect_to(onboarding_step1_path)
      patch onboarding_complete_path
      expect(response).to redirect_to(business_project_path(project))
    end
  end

  describe "無効な招待" do
    it "登録後に対象が削除されたら、案内を出して Business ホームへ戻す" do
      get business_community_path(community)
      newcomer = register("deleted-target@example.com")
      community.destroy!

      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      go_through_onboarding
      expect(response).to redirect_to(business_root_path)
      expect(flash[:alert]).to include("招待されたコミュニティ・プロジェクトを開けませんでした")
      expect(BusinessSignupInvitation.exists?(customer_id: newcomer.id)).to be false
    end

    it "期限切れなら、案内を出して Business ホームへ戻す" do
      get business_project_path(project)
      newcomer = register("expired@example.com")
      newcomer.confirm
      sign_in_via_form(self, newcomer)

      travel(BusinessSignupInvitation::TTL + 1.minute) do
        patch onboarding_complete_path
      end
      expect(response).to redirect_to(business_root_path)
      expect(flash[:alert]).to include("有効期限")
    end

    it "存在しない・Business 以外の対象を開いていた場合は招待先を記録せず、通常の遷移になる" do
      music_community = create(:community, owner: owner, domain: music_domain)

      [business_community_path(0), business_community_path(music_community)].each_with_index do |path, index|
        get path
        newcomer = register("not-invite-#{index}@example.com")
        expect(newcomer.business_signup_invitation).to be_nil
        reset!
      end
    end
  end

  it "招待先の記録に失敗しても登録は完了し、同じブラウザなら従来どおり確認後に招待先へ戻る" do
    allow(Business::SignupInvitations::Remember).to receive(:call).and_raise(ActiveRecord::StatementInvalid, "boom")

    get business_community_path(community)
    newcomer = register("remember-failed@example.com")
    expect(newcomer.business_signup_invitation).to be_nil

    get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
    expect(response).to redirect_to(business_community_path(community))
  end

  describe "従来の挙動を保つもの" do
    it "招待用URLを経由しない新規登録は、確認後に Business ホームへ進み、招待先を記録しない" do
      newcomer = register("plain-signup@example.com")
      expect(newcomer.business_signup_invitation).to be_nil

      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      expect(response).to redirect_to(business_root_path)
      patch onboarding_complete_path
      expect(response).to redirect_to(business_root_path)
    end

    it "詳細画面以外の Business の画面は、従来どおり同じブラウザの確認後にその画面へ戻す" do
      get business_timeline_path
      newcomer = register("timeline-signup@example.com")
      expect(newcomer.business_signup_invitation).to be_nil

      get customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
      expect(response).to redirect_to(business_timeline_path)
    end

    it "既存会員は招待先を記録せず、ログイン後に開いたページへ戻る" do
      member = create(:customer, domain_name: "business", onboarding_done: true)

      get business_community_path(community)
      sign_in_via_form(self, member)

      expect(response).to redirect_to(business_community_path(community))
      expect(BusinessSignupInvitation.count).to eq 0
    end
  end
end
