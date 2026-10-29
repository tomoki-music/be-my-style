require "rails_helper"

# ログイン後ホーム(/ と /business)を実ブラウザで確認する。データはすべて検証用の架空のもの。
RSpec.describe "ログイン後ホーム", type: :system, js: true do
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:host) { create(:customer, name: "運営テストユーザー", domain_name: "business") }
  let(:viewer) do
    create(:customer, :customer_with_parts, name: "ホーム確認ユーザー", onboarding_done: true).tap do |customer|
      CustomerDomain.create!(customer: customer, domain: business_domain)
    end
  end

  let!(:session_club) { community!("駅前セッションの会", music_domain, 1, introduction: "毎月第2土曜に駅前スタジオでセッションしています。初心者歓迎です。") }
  let!(:acoustic_club) { community!("週末アコースティック部", music_domain, 2, owner: viewer, introduction: "アコースティック編成で週末に集まるコミュニティです。") }
  let!(:planning_lab) { community!("地域イベント企画ラボ", business_domain, 3, introduction: "地域のイベントを企画・運営する仲間の集まりです。") }
  let!(:design_club) { community!("デザイン勉強会", business_domain, 4) }
  let!(:festival) { project!("夏祭りステージ運営", 1) }
  let!(:flyer) { project!("フライヤー制作", 2, customer: viewer) }
  let!(:streaming) { project!("配信機材の検討", 3) }

  before do
    [session_club, acoustic_club, planning_lab].each { |community| CommunityCustomer.create!(community: community, customer: viewer) }
    Permit.create!(community: design_club, customer: viewer)
    ProjectMember.create!(project: festival, customer: viewer)
    ProjectJoinRequest.create!(project: streaming, customer: viewer)
  end

  def community!(name, domain, order, owner: host, introduction: "検証用のコミュニティです。")
    create(:community, name: name, domain: domain, owner: owner, introduction: introduction).tap do |community|
      community.update_columns(updated_at: order.minutes.ago)
    end
  end

  def project!(title, order, customer: host)
    Project.create!(community: planning_lab, customer: customer, title: title).tap { |project| project.update_columns(updated_at: order.minutes.ago) }
  end

  def sign_in_via_form(customer = viewer)
    visit new_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_current_path(root_path, wait: 10)
  end

  # CDP の viewport 上書きは描画済みのページでないと効かないため、ログイン後に呼ぶ。
  def set_viewport(width, height = 900)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 600
    )
  end

  # ホーム本文(.member-home)内の要素が画面外へはみ出さず、カード同士が重ならないこと。
  # 共通ヘッダーの既存の横はみ出し(SP)は別課題のため、本文だけを測る。
  def member_home_layout
    page.evaluate_script(<<~JS)
      (function () {
        var width = document.documentElement.clientWidth;
        var overflow = 0;
        document.querySelectorAll(".member-home *").forEach(function (el) {
          var r = el.getBoundingClientRect();
          if (r.width === 0 && r.height === 0) return;
          overflow = Math.max(overflow, r.right - width, -r.left);
        });
        var cards = Array.from(document.querySelectorAll(".member-home-card")).map(function (el) { return el.getBoundingClientRect(); });
        var overlap = cards.some(function (a, i) {
          return cards.some(function (b, j) {
            return i < j && a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1;
          });
        });
        var firstRow = cards.length ? cards.filter(function (r) { return Math.abs(r.top - cards[0].top) < 1; }).length : 0;
        return { overflow: Math.ceil(overflow), overlap: overlap, cards: cards.length, columns: firstRow };
      })()
    JS
  end

  def page_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  # 画面外(左右)にはみ出している要素。ヘッダー・メニューも含めたページ全体で測る。
  def clipped_elements(selector = "body *")
    page.evaluate_script(<<~JS, selector)
      (function (selector) {
        var width = document.documentElement.clientWidth;
        return Array.from(document.querySelectorAll(selector)).filter(function (el) {
          var r = el.getBoundingClientRect();
          return (r.width > 0 || r.height > 0) && (r.right > width + 0.5 || r.left < -0.5);
        }).map(function (el) { return el.tagName + "." + el.className; });
      })(arguments[0])
    JS
  end

  def screenshot!(name)
    page.save_screenshot(Rails.root.join("tmp/screenshots/#{name}.png").to_s)
  end

  { 375 => 1, 768 => 2, 1280 => 3 }.each do |width, columns|
    it "幅#{width}px: / のホームが#{columns}列で崩れず、はみ出さない" do
      sign_in_via_form
      set_viewport(width, width < 600 ? 2200 : 1300)
      visit root_path

      expect(page).to have_css("#my-communities .member-home-card", count: 4)
      expect(page).to have_css("#my-projects .member-home-card", count: 3)
      expect(page).to have_no_css(".slider, .parallax, .top-cta")
      expect(member_home_layout).to eq("overflow" => 0, "overlap" => false, "cards" => 7, "columns" => columns)
      screenshot!("member_home_music_#{width}")
    end
  end

  it "幅375px: /business のホームも崩れず、はみ出さない" do
    sign_in_via_form
    set_viewport(375, 2200)
    visit business_root_path

    expect(page).to have_css(".header_container--business")
    expect(page).to have_no_css(".hero-section, .business-top-slider")
    expect(member_home_layout).to include("overflow" => 0, "overlap" => false, "cards" => 7)
    expect(page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")).to be <= 0
    screenshot!("member_home_business_375")
  end

  it "幅1280px: /business のホーム" do
    sign_in_via_form
    set_viewport(1280, 1300)
    visit business_root_path

    expect(member_home_layout).to include("overflow" => 0, "overlap" => false, "columns" => 3)
    screenshot!("member_home_business_1280")
  end

  context "幅375px: ヘッダーを含むページ全体" do
    it "/ はページ全体が横にはみ出さず、SP メニュー(アバター)を開くと全項目が画面内で押せる" do
      sign_in_via_form
      set_viewport(375)
      visit root_path

      expect(page_overflow).to be <= 0
      expect(clipped_elements).to eq []
      expect(page).to have_css("#open .sp-menu-open", visible: :visible)

      find("#open").click
      expect(page).to have_css(".customer-menu-sp a", text: "コミュニティ一覧", visible: :visible, wait: 5)
      expect(clipped_elements(".customer-menu-sp a, .customer-menu-sp button, .customer-menu-sp summary")).to eq []
      expect(page_overflow).to be <= 0
      find(".customer-menu-sp a", text: "コミュニティ一覧").click
      expect(page).to have_current_path(public_communities_path, wait: 10)
    end

    it "/business はページ全体が横にはみ出さず、☰メニューを開くと全項目が画面内で押せる" do
      sign_in_via_form
      set_viewport(375)
      visit business_root_path

      expect(page_overflow).to be <= 0
      expect(clipped_elements).to eq []

      find("button#open").click
      expect(page).to have_css("#businessSpMenu a", text: "プロジェクト", visible: :visible, wait: 5)
      expect(clipped_elements("#businessSpMenu a, #businessSpMenu button")).to eq []
      expect(page_overflow).to be <= 0
    end
  end

  context "利用者の種類ごとの見え方" do
    it "一般参加者: 参加中のものだけが並び、探す導線が見出し横にある" do
      member = create(:customer, :customer_with_parts, name: "一般参加テストユーザー", onboarding_done: true)
      CustomerDomain.create!(customer: member, domain: business_domain)
      CommunityCustomer.create!(community: session_club, customer: member)
      CommunityCustomer.create!(community: planning_lab, customer: member)
      ProjectMember.create!(project: festival, customer: member)

      sign_in_via_form(member)
      set_viewport(1280, 1100)
      visit root_path

      expect(all("#my-communities .member-home-card__status").map(&:text)).to eq %w[参加中 参加中]
      expect(all("#my-projects .member-home-card__status").map(&:text)).to eq %w[参加中]
      expect(page).to have_no_text("週末アコースティック部")
      expect(page).to have_no_text("フライヤー制作")
      expect(page).to have_css("#my-communities .member-home__header-link", text: "Businessコミュニティを探す")
      expect(page).to have_css("#my-projects .member-home__header-link", text: "プロジェクトを探す")
      screenshot!("member_home_persona_member_1280")
    end

    it "承認待ちのみ: 状態と承認後の案内だけを出し、紹介文や中身は出さない" do
      applicant = create(:customer, :customer_with_parts, name: "申請中テストユーザー", onboarding_done: true)
      CustomerDomain.create!(customer: applicant, domain: business_domain)
      Permit.create!(community: design_club, customer: applicant)
      Permit.create!(community: planning_lab, customer: applicant)

      sign_in_via_form(applicant)
      set_viewport(375, 1500)
      visit root_path

      expect(all("#my-communities .member-home-card__status").map(&:text)).to eq %w[承認待ち 承認待ち]
      expect(page).to have_no_text("地域のイベントを企画・運営する仲間の集まりです。")
      expect(page).to have_no_text("夏祭りステージ運営")
      expect(page).to have_css("#my-projects .member-home__empty", text: "参加しているプロジェクトはまだありません。")
      expect(page_overflow).to be <= 0
      screenshot!("member_home_persona_pending_375")

      find(%(a[aria-label="地域イベント企画ラボの詳細を見る"])).click
      expect(page).to have_current_path(business_community_path(planning_lab), wait: 10)
      expect(page).to have_no_text("夏祭りステージ運営")
    end

    it "管理者: 自分に関係するものだけを並べ、関係の無いコミュニティも既存の一覧・詳細から管理できる" do
      admin = create(:customer, :customer_with_parts, name: "管理者テストユーザー", onboarding_done: true, is_owner: :admin)
      CustomerDomain.create!(customer: admin, domain: business_domain)
      CommunityCustomer.create!(community: session_club, customer: admin)

      sign_in_via_form(admin)
      set_viewport(1280, 1100)
      visit root_path

      expect(all("#my-communities .member-home-card__title").map(&:text)).to eq %w[駅前セッションの会]
      expect(find("#my-communities .member-home-card__status").text).to eq "運営"
      expect(page).to have_css("#my-projects .member-home__empty")
      screenshot!("member_home_persona_admin_1280")

      find("#my-communities .member-home__header-link", text: "Businessコミュニティを探す").click
      expect(page).to have_current_path(business_communities_path, wait: 10)
      expect(page).to have_text("地域イベント企画ラボ")

      visit business_community_path(planning_lab)
      expect(page).to have_link("メンバー管理", href: business_permits_path(planning_lab))
      visit business_project_path(festival)
      expect(page).to have_link("編集", href: edit_business_project_path(festival))
    end

    it "所属0件(Business 未登録): 空状態から既存の一覧と Business 利用開始へ進める" do
      newcomer = create(:customer, :customer_with_parts, name: "新規テストユーザー", onboarding_done: true)

      sign_in_via_form(newcomer)
      set_viewport(375, 1000)
      visit root_path

      expect(page).to have_no_css(".member-home-card")
      expect(page).to have_css("#my-communities .member-home__empty a", text: "音楽コミュニティを探す")
      expect(page).to have_no_css("#my-communities a", text: "Businessコミュニティを探す")
      expect(page_overflow).to be <= 0
      screenshot!("member_home_persona_empty_375")

      find("#my-projects a", text: "NAKAMAの利用を始める").click
      expect(page).to have_current_path(business_join_path, wait: 10)

      visit root_path
      find("#my-communities a", text: "音楽コミュニティを探す").click
      expect(page).to have_current_path(public_communities_path, wait: 10)
      expect(page).to have_text("駅前セッションの会")
    end
  end

  it "カードのボタンから、コミュニティ詳細・イベント一覧・プロジェクト詳細へ移動できる" do
    sign_in_via_form

    within("#my-communities") { find(%(a[aria-label="駅前セッションの会の詳細を見る"])).click }
    expect(page).to have_current_path(public_community_path(session_club), wait: 10)

    visit root_path
    within("#my-communities") { find(%(a[aria-label="駅前セッションの会のイベントを見る"])).click }
    expect(page).to have_current_path(public_events_path(community_id: session_club.id, status: "upcoming"), wait: 10)

    visit root_path
    within("#my-communities") { find(%(a[aria-label="地域イベント企画ラボの詳細を見る"])).click }
    expect(page).to have_current_path(business_community_path(planning_lab), wait: 10)

    visit root_path
    within("#my-projects") { find(%(a[aria-label="夏祭りステージ運営を開く"])).click }
    expect(page).to have_current_path(business_project_path(festival), wait: 10)
  end

  it "キーボード(Tab)でカードのボタンへ移動して開ける" do
    sign_in_via_form
    first_button = find("#my-communities .member-home-card__actions a", match: :first)
    page.execute_script("arguments[0].focus()", first_button)
    expect(page.evaluate_script("document.activeElement.textContent.trim()")).to eq "詳細を見る"

    first_button.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.textContent.trim()")).to eq "イベントを見る"

    page.driver.browser.switch_to.active_element.send_keys(:enter)
    expect(page).to have_current_path(public_events_path(community_id: session_club.id, status: "upcoming"), wait: 10)
  end
end
