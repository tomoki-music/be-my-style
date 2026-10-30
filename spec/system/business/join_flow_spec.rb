require "rails_helper"

# 一般の Business 利用者が、ホーム → コミュニティを探す → 詳細で参加 → プロジェクト詳細で参加 → スレッド
# と実ブラウザで進めること。参加ボタンが固定ナビ(SP の下部ナビ)に隠れず、最初の表示で見えることも確かめる。
RSpec.describe "Business の参加導線(実ブラウザ)", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, name: "運営 さくら", domain_name: "business", onboarding_done: true) }
  let(:general) { create(:customer, name: "一般 たろう", domain_name: "business", onboarding_done: true) }
  let(:admin) { create(:customer, name: "管理 はなこ", domain_name: "business", onboarding_done: true, is_owner: :admin) }

  let!(:manual_community) do
    Community.create!(name: "デザイン勉強会", introduction: "UIデザインを学び合うコミュニティです。月1回のレビュー会を開いています。",
                      owner: owner, domain: business_domain, required_plan_for_event_creation: "premium", join_approval_mode: :manual)
  end
  let!(:auto_community) do
    Community.create!(name: "スタートアップ交流会", introduction: "起業準備中の人が気軽に相談し合う場です。",
                      owner: owner, domain: business_domain, required_plan_for_event_creation: "premium", join_approval_mode: :auto)
  end
  let!(:auto_project) do
    Project.create!(community: auto_community, customer: owner, title: "ピッチ練習会", description: "1分ピッチを練習し合います。",
                    join_approval_mode: :auto)
  end

  before do
    CommunityCustomer.create!(community: manual_community, customer: owner)
    CommunityCustomer.create!(community: auto_community, customer: owner)
  end

  def sign_in_as(customer)
    visit new_business_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_css(".ba-main", wait: 10)
  end

  def screenshot!(name)
    page.save_screenshot(Rails.root.join("tmp/screenshots/business_join_#{name}.png").to_s)
  end

  def rect(selector)
    page.evaluate_script("(function(){var r=document.querySelector(#{selector.to_json}).getBoundingClientRect();return {top: r.top, bottom: r.bottom};})()")
  end

  # 最初の表示(スクロール前)で画面内にあり、SP の下部ナビにも重ならないこと。
  def expect_visible_without_scroll(selector)
    page.execute_script("window.scrollTo(0, 0)")
    box = rect(selector)
    viewport_bottom = page.evaluate_script("window.innerHeight")
    nav_visible = page.evaluate_script("getComputedStyle(document.querySelector('.ba-bottomnav')).display !== 'none'")
    limit = nav_visible ? rect(".ba-bottomnav")["top"] : viewport_bottom
    expect(box["top"]).to be >= 0
    expect(box["bottom"]).to be <= limit
  end

  def expect_no_horizontal_overflow
    expect(page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")).to be <= 0
  end

  it "スマホ(375px): ホームから自動承認のコミュニティとプロジェクトに参加し、スレッドを開ける" do
    sign_in_as(general)
    use_mobile_viewport(width: 375, height: 812)
    visit business_root_path
    screenshot!("sp_home_empty")

    click_link "コミュニティを探す", match: :first
    expect(page).to have_css(".ba-community-tile", count: 2)
    expect_no_horizontal_overflow
    screenshot!("sp_communities")

    find(".ba-community-tile", text: "スタートアップ交流会").click
    expect(page).to have_css("#community-join a", text: "参加する")
    expect_visible_without_scroll("#community-join a.ba-btn--primary")
    expect_no_horizontal_overflow
    screenshot!("sp_community_none_auto")

    click_link "参加する"
    expect(page).to have_css("#community-join .ba-status", text: "参加中")
    screenshot!("sp_community_member")

    click_link "プロジェクトを見る"
    find(".ba-project-card", text: "ピッチ練習会").click
    expect(page).to have_css("#project-join a", text: "参加する")
    expect_visible_without_scroll("#project-join a.ba-btn--primary")
    screenshot!("sp_project_none_auto")

    click_link "参加する"
    expect(page).to have_css("#project-join .ba-status", text: "参加中")
    screenshot!("sp_project_member")

    click_link "スレッドを見る"
    find("#threads a", text: "全体トーク", match: :first).click
    expect(page).to have_css(".business-composer__textarea")
  end

  it "スマホ(375px): 手動承認は申請・承認待ち・取り消しができ、停止中は理由だけを出す" do
    sign_in_as(general)
    use_mobile_viewport(width: 375, height: 812)
    visit business_community_path(manual_community)
    expect(page).to have_css("#community-join a", text: "参加を申請する")
    expect_visible_without_scroll("#community-join a.ba-btn--primary")
    screenshot!("sp_community_none_manual")

    click_link "参加を申請する"
    expect(page).to have_css("#community-join .ba-status", text: "承認待ち")
    expect_visible_without_scroll("#community-join a.ba-btn--secondary")
    screenshot!("sp_community_pending")

    accept_confirm { click_link "申請を取り消す" }
    expect(page).to have_css("#community-join a", text: "参加を申請する")
    expect(Permit.where(community: manual_community, customer: general)).to be_empty

    CommunityAccessSuspension.create!(community: manual_community, customer: general)
    visit business_community_path(manual_community)
    expect(page).to have_css("#community-join .ba-status", text: "アクセス停止中")
    expect(page).to have_no_css("#community-join a")
    screenshot!("sp_community_suspended")
  end

  it "PC(1280px): 一覧カードの導線と、運営者・管理者の状態表示" do
    sign_in_as(general)
    use_desktop_viewport
    visit business_communities_path
    expect(page).to have_css(".ba-community-tile__cta", text: "詳細・参加方法を見る", count: 2)
    screenshot!("pc_communities")

    find(".ba-community-tile", text: "デザイン勉強会").click
    expect(page).to have_css("#community-join a", text: "参加を申請する")
    expect_visible_without_scroll("#community-join a.ba-btn--primary")
    screenshot!("pc_community_none_manual")

    Capybara.reset_sessions!
    sign_in_as(admin)
    use_desktop_viewport
    visit business_community_path(manual_community)
    expect(page).to have_css("#community-join .ba-status", text: "管理権限あり")
    expect(page).to have_text("管理者のため、参加申請なしで閲覧・管理できます。")
    screenshot!("pc_community_admin")

    Capybara.reset_sessions!
    sign_in_as(owner)
    use_desktop_viewport
    visit business_project_path(auto_project)
    expect(page).to have_css("#project-join .ba-status", text: "運営")
    screenshot!("pc_project_operator")
  end
end
