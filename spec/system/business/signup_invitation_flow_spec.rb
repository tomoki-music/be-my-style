require "rails_helper"

# 招待用URLを未ログインで開いた人が、新規登録 → 確認メール → オンボーディングを実ブラウザで通し、招待先の詳細画面に着くこと。
# 確認メールのリンクは、Cookie を消した状態(別のブラウザ・アプリで開いた想定)で開く。データはすべて架空。
RSpec.describe "Business 招待用URLからの新規登録(ブラウザ)", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true, name: "招待した人") }
  let(:community) do
    create(:community, owner: owner, domain: business_domain, name: "地域企画ラボ", join_approval_mode: :auto,
                       introduction: "地域の企画が好きな人が集まるコミュニティです。")
  end
  let(:project) { Project.create!(community: community, customer: owner, title: "商店街の魅力発信", description: "取材記事をつくります。") }

  before { CommunityCustomer.create!(community: community, customer: owner) }

  def sign_up_from_invite(invite_path, email)
    visit invite_path
    expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
    click_link "新規登録はこちら"

    fill_in "customer_name", with: "招待された人"
    fill_in "customer_email", with: email
    fill_in "customer_password", with: "password"
    fill_in "customer_password_confirmation", with: "password"
    click_button "登録する"
    expect(page).to have_current_path(new_business_customer_session_path, wait: 10)

    Customer.find_by!(email: email)
  end

  # 別のブラウザで確認メールのリンクを開いた想定(Cookie を持たない)。
  def confirm_in_other_browser(customer)
    Capybara.reset_session!
    visit customer_confirmation_path(confirmation_token: customer.confirmation_token)
    expect(page).to have_current_path(onboarding_step1_path, wait: 10)
  end

  def finish_onboarding(customer, join_community: nil)
    click_link "スタートする"
    expect(page).to have_current_path(onboarding_step2_path, wait: 10)
    if join_community
      within(".community-card", text: join_community.name) { click_link "参加する →" }
      # 自動承認の参加は申請(Permit)を作らないため、オンボーディングの一覧の表示は変わらない(既存の表示)。参加の記録で待つ。
      Timeout.timeout(10) { sleep 0.1 until CommunityCustomer.exists?(community: join_community, customer: customer) }
    end
    click_link "次へ進む"
    expect(page).to have_current_path(onboarding_step3_path, wait: 10)
    click_link "準備完了！"
  end

  { "スマホ" => [:mobile, -> { use_mobile_viewport }], "PC" => [:desktop, -> { use_desktop_viewport }] }.each do |label, (viewport_key, viewport)|
    it "#{label}: コミュニティの招待用URLから登録すると、オンボーディング完了後にコミュニティの詳細画面に着く" do
      visit new_business_customer_session_path
      instance_exec(&viewport)

      newcomer = sign_up_from_invite(business_community_path(community), "invited-community-#{viewport_key}@example.com")
      confirm_in_other_browser(newcomer)
      finish_onboarding(newcomer)

      expect(page).to have_current_path(business_community_path(community), wait: 10)
      expect(page).to have_css("h1", text: "地域企画ラボ")
      expect(page).to have_link("参加する")
      expect(BusinessSignupInvitation.exists?(customer_id: newcomer.id)).to be false
    end
  end

  it "プロジェクトの招待用URLから登録し、オンボーディングでコミュニティに参加すると、プロジェクトの詳細画面に着く" do
    visit new_business_customer_session_path
    use_mobile_viewport

    newcomer = sign_up_from_invite(business_project_path(project), "invited-project@example.com")
    confirm_in_other_browser(newcomer)
    finish_onboarding(newcomer, join_community: community)

    expect(page).to have_current_path(business_project_path(project), wait: 10)
    expect(page).to have_css("h1", text: "商店街の魅力発信")

    # 次回の通常ログインでは招待先へ転送しない。
    Capybara.reset_session!
    visit new_business_customer_session_path
    fill_in "customer_email", with: newcomer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  def log_in(customer)
    Capybara.reset_session!
    visit new_business_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
  end

  # 親コミュニティに参加しないままオンボーディングを終え、コミュニティの参加案内に着くまで。
  def arrive_at_community_guidance(email)
    newcomer = sign_up_from_invite(business_project_path(project), email)
    confirm_in_other_browser(newcomer)
    finish_onboarding(newcomer)

    expect(page).to have_current_path(business_community_path(community), wait: 10)
    expect(page).to have_text("招待されたプロジェクト「商店街の魅力発信」を開くには、先にこのコミュニティへの参加が必要です")
    newcomer
  end

  it "親コミュニティ未参加(自動承認): 参加案内から参加すると、元の招待プロジェクトへ進み、次回ログインでは転送しない" do
    visit new_business_customer_session_path
    use_mobile_viewport

    newcomer = arrive_at_community_guidance("guidance-auto@example.com")
    within("#community-join") { click_link "参加する" }

    expect(page).to have_current_path(business_project_path(project), wait: 10)
    expect(page).to have_css("h1", text: "商店街の魅力発信")
    expect(page).to have_text("コミュニティに参加しました")

    log_in(newcomer)
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  it "親コミュニティ未参加(承認制): 申請 → 運営者の承認 → ログインで元の招待プロジェクトへ進み、その後のログインでは転送しない" do
    community.update!(join_approval_mode: :manual)
    visit new_business_customer_session_path
    use_desktop_viewport

    newcomer = arrive_at_community_guidance("guidance-manual@example.com")
    within("#community-join") { click_link "参加を申請する" }
    expect(page).to have_text("コミュニティへ参加申請しました", wait: 10)
    expect(page).to have_current_path(business_community_path(community))

    # 承認前のログインでは転送しない。
    log_in(newcomer)
    expect(page).to have_current_path(business_root_path, wait: 10)

    # 運営者がメンバー管理画面で承認する(既存の承認フロー)。
    log_in(owner)
    expect(page).to have_current_path(business_root_path, wait: 10)
    visit business_permits_path(community)
    within(".ba-row", text: "招待された人") { click_link "承認" }
    expect(page).to have_text("コミュニティへ参加を許可しました", wait: 10)

    log_in(newcomer)
    expect(page).to have_current_path(business_project_path(project), wait: 10)
    expect(page).to have_css("h1", text: "商店街の魅力発信")

    log_in(newcomer)
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  it "招待用URLを経由しない新規登録は、従来どおり確認後に Business ホームへ進む" do
    visit new_business_customer_session_path
    click_link "新規登録はこちら"
    fill_in "customer_name", with: "ふつうに登録した人"
    fill_in "customer_email", with: "plain@example.com"
    fill_in "customer_password", with: "password"
    fill_in "customer_password_confirmation", with: "password"
    click_button "登録する"
    expect(page).to have_current_path(new_business_customer_session_path, wait: 10)

    newcomer = Customer.find_by!(email: "plain@example.com")
    expect(newcomer.business_signup_invitation).to be_nil
    Capybara.reset_session!
    visit customer_confirmation_path(confirmation_token: newcomer.confirmation_token)
    expect(page).to have_current_path(business_root_path, wait: 10)
  end
end
