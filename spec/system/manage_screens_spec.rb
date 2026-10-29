require "rails_helper"

# 通常画面・編集画面・メンバー管理画面を実ブラウザで確認する。データはすべて検証用の架空のもの。
RSpec.describe "通常画面・編集画面・メンバー管理画面", type: :system, js: true do
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:manager) do
    create(:customer, :customer_with_parts, name: "運営テスト花子", onboarding_done: true).tap do |customer|
      CustomerDomain.create!(customer: customer, domain: business_domain)
    end
  end
  let(:member) do
    create(:customer, :customer_with_parts, name: "参加テスト太郎", onboarding_done: true).tap do |customer|
      CustomerDomain.create!(customer: customer, domain: business_domain)
    end
  end
  let(:applicant) { create(:customer, name: "申請テスト次郎", domain_name: "business") }

  let!(:business_community) do
    create(:community, name: "地域イベント企画ラボ", domain: business_domain, owner: manager,
                       introduction: "地域のイベントを企画・運営する仲間の集まりです。\n\n## 活動\n- 月1回の企画会議\n- 夏祭りの運営")
  end
  let!(:project) do
    Project.create!(community: business_community, customer: manager, title: "夏祭りステージ運営",
                    description: "ステージの進行表と機材手配をまとめます。", goal: "8月の本番を無事に終える", status: "recruiting")
  end
  let!(:music_community) do
    create(:community, name: "駅前セッションの会", domain: music_domain, owner: manager,
                       introduction: "毎月第2土曜に駅前スタジオでセッションしています。初心者歓迎です。")
  end

  before do
    [manager, member].each do |customer|
      CommunityCustomer.create!(community: business_community, customer: customer)
      CommunityCustomer.create!(community: music_community, customer: customer)
    end
    ProjectMember.create!(project: project, customer: member)
    Permit.create!(community: business_community, customer: applicant)
    Permit.create!(community: music_community, customer: applicant)
    CommunityCustomer.create!(community: business_community, customer: applicant).destroy
    ProjectJoinRequest.create!(project: project, customer: create(:customer, name: "申請テスト三郎", domain_name: "business").tap { |c| CommunityCustomer.create!(community: business_community, customer: c) })
    room = ChatRoom.create!
    ChatRoomCustomer.create!(chat_room: room, community: music_community, customer: manager)
  end

  def sign_in_via_form(customer)
    visit new_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_current_path(root_path, wait: 10)
  end

  # CDP の viewport 上書きは描画済みのページでないと効かないため、ログイン後に呼ぶ。
  def set_viewport(width, height = 1400)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 600
    )
  end

  def page_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  # 管理メニューのリンクがすべて画面内にあり、押せる大きさ(高さ 36px 以上)であること。
  def manage_bar_links_inside?
    page.evaluate_script(<<~JS)
      (function () {
        var width = document.documentElement.clientWidth;
        var links = Array.from(document.querySelectorAll(".manage-bar__link"));
        return links.length > 0 && links.every(function (el) {
          var r = el.getBoundingClientRect();
          return r.left >= 0 && r.right <= width && r.height >= 36;
        });
      })()
    JS
  end

  def screenshot!(name)
    page.save_screenshot(Rails.root.join("tmp/screenshots/#{name}.png").to_s)
  end

  pages = {
    "business_community_show" => ->(t) { t.business_community_path(t.business_community) },
    "business_community_edit" => ->(t) { t.edit_business_community_path(t.business_community) },
    "business_community_members" => ->(t) { t.business_permits_path(t.business_community) },
    "project_show" => ->(t) { t.business_project_path(t.project) },
    "project_edit" => ->(t) { t.edit_business_project_path(t.project) },
    "project_members" => ->(t) { t.members_business_project_path(t.project) },
    "music_community_show" => ->(t) { t.public_community_path(t.music_community) },
    "music_community_edit" => ->(t) { t.edit_public_community_path(t.music_community) },
    "music_community_members" => ->(t) { t.public_permits_path(t.music_community) },
    "project_management" => ->(t) { t.business_community_project_management_path(t.business_community) },
    "project_new" => ->(t) { t.new_business_project_path(community_id: t.business_community.id) }
  }

  [375, 1280].each do |width|
    it "幅#{width}px: 管理者の11画面がページ全体で横にはみ出さず、管理メニューが画面内で押せる" do
      sign_in_via_form(manager)
      set_viewport(width)

      results = pages.to_h do |name, path|
        visit path.call(self)
        expect(page).to have_css(name == "project_new" ? ".project-new-community" : "nav.manage-bar")
        [name, { "overflow" => page_overflow, "links_inside" => name == "project_new" || manage_bar_links_inside? }]
      end

      expect(results.values).to all(eq("overflow" => 0, "links_inside" => true))
    end
  end

  it "スクリーンショット(PC 1280px / スマホ 375px)" do
    sign_in_via_form(manager)
    {
      "manage_business_community_show" => [business_community_path(business_community), [1280, 375]],
      "manage_business_community_edit" => [edit_business_community_path(business_community), [1280, 375]],
      "manage_business_community_members" => [business_permits_path(business_community), [375]],
      "manage_project_show" => [business_project_path(project), [1280, 375]],
      "manage_project_edit" => [edit_business_project_path(project), [375]],
      "manage_project_members" => [members_business_project_path(project), [375]],
      "manage_music_community_show" => [public_community_path(music_community), [1280, 375]],
      "manage_music_community_edit" => [edit_public_community_path(music_community), [375]],
      "manage_project_management" => [business_community_project_management_path(business_community), [1280, 375]],
      "manage_project_new" => [new_business_project_path(community_id: business_community.id), [375]]
    }.each do |name, (path, widths)|
      widths.each do |width|
        set_viewport(width, width < 600 ? 1600 : 1100)
        visit path
        expect(page).to have_css(name == "manage_project_new" ? ".project-new-community" : "nav.manage-bar")
        screenshot!("#{name}_#{width}")
      end
    end

    set_viewport(375, 900)
    visit edit_business_community_path(business_community)
    page.execute_script("document.getElementById('project-management').scrollIntoView()")
    screenshot!("manage_business_community_edit_project_section_375")

    Capybara.reset_session!
    sign_in_via_form(member)
    set_viewport(375, 1600)
    visit business_community_path(business_community)
    expect(page).to have_no_css("nav.manage-bar")
    screenshot!("manage_business_community_show_participant_375")
  end

  it "管理者は通常画面から編集へ進み、キャンセルでは保存されず、保存すると通常画面に成功メッセージが出る" do
    sign_in_via_form(manager)
    visit business_community_path(business_community)

    within("nav.manage-bar") { click_link "編集" }
    expect(page).to have_current_path(edit_business_community_path(business_community))
    fill_in "community[name]", with: "キャンセルする名前"
    click_link "キャンセル"
    expect(page).to have_current_path(business_community_path(business_community))
    expect(page).to have_css("h1", text: "地域イベント企画ラボ")
    expect(business_community.reload.name).to eq "地域イベント企画ラボ"

    within("nav.manage-bar") { click_link "編集" }
    # Turbolinks がキャッシュした編集画面(キャンセル前の入力が残ったもの)を先に描くため、
    # 保存済みの値が入った本物の画面に置き換わるのを待ってから操作する。
    field = find_field("community[name]", with: "地域イベント企画ラボ")
    # fill_in で空文字を入れても Selenium では欄が空にならないことがあるため、値を直接空にする。
    page.execute_script("arguments[0].value = ''", field)
    click_button "保存する"
    expect(page).to have_css(".alert-danger")
    expect(page).to have_css("nav.manage-bar [aria-current='page']", text: "編集")

    fill_in "community[name]", with: "地域イベント企画ラボ2"
    click_button "保存する"
    expect(page).to have_current_path(business_community_path(business_community))
    expect(page).to have_content("更新しました")
    expect(page).to have_css("h1", text: "地域イベント企画ラボ2")

    within("nav.manage-bar") { click_link "メンバー管理" }
    expect(page).to have_current_path(business_permits_path(business_community))
    expect(page).to have_content("申請テスト次郎")
    within("nav.manage-bar") { click_link "通常画面" }
    expect(page).to have_current_path(business_community_path(business_community))
  end

  it "プロジェクトも通常画面 → 編集 → 保存で通常画面へ戻り、スレッドへの導線が残る" do
    sign_in_via_form(manager)
    visit business_project_path(project)

    expect(page).to have_css("#threads")
    within("nav.manage-bar") { click_link "編集" }
    fill_in "project[title]", with: "夏祭りステージ運営（確定版）"
    click_button "保存する"

    expect(page).to have_current_path(business_project_path(project))
    expect(page).to have_content("更新しました！")
    expect(page).to have_css("h1", text: "夏祭りステージ運営（確定版）")
    expect(page).to have_link("＋ 新しいスレッド")
  end

  it "管理メニュー → 編集 → プロジェクト管理セクションから、プロジェクトを作成できる" do
    sign_in_via_form(manager)
    visit business_community_path(business_community)
    expect(page).to have_no_link("＋ 作成")

    within("nav.manage-bar") { click_link "編集" }
    within("#project-management") { click_link "新しいプロジェクトを作成" }
    expect(page).to have_css(".project-new-community strong", text: "地域イベント企画ラボ")
    fill_in "project[title]", with: "秋の収穫祭ブース"
    click_button "作成する"

    expect(page).to have_current_path(business_community_path(business_community))
    expect(page).to have_content("プロジェクトを作成しました")
    expect(page).to have_css(".project-grid", text: "秋の収穫祭ブース")
  end

  it "一般参加者は管理メニューが出ず、編集画面の URL を開いても通常画面へ戻される" do
    sign_in_via_form(member)

    visit business_project_path(project)
    expect(page).to have_no_css("nav.manage-bar")
    expect(page).to have_css("#threads")

    visit edit_business_project_path(project)
    expect(page).to have_current_path(business_project_path(project))
    expect(page).to have_content("このプロジェクトを管理する権限がありません。")

    visit edit_business_community_path(business_community)
    expect(page).to have_current_path(business_community_path(business_community))
    expect(page).to have_content("このコミュニティを編集する権限がありません。")
  end
end
