require "rails_helper"

# Business ログイン後の枠(layouts/business)で、固定ナビが操作を妨げないこと・共用画面との行き来を実ブラウザで確認する。
RSpec.describe "Business の固定ナビと画面の行き来", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, name: "運営 確認ユーザー", domain_name: "business", onboarding_done: true) }
  let(:community) do
    Community.create!(name: "ナビ確認コミュニティ", introduction: "確認用", owner: owner, domain: business_domain,
                      required_plan_for_event_creation: "premium")
  end
  let(:project) { Project.create!(community: community, customer: owner, title: "ナビ確認プロジェクト", description: "確認用") }

  before { CommunityCustomer.create!(community: community, customer: owner) }

  def sign_in_as(customer)
    visit new_business_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  def mobile!
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 375, height: 812, deviceScaleFactor: 1, mobile: true)
  end

  def rect(selector)
    page.evaluate_script("(function(){var r=document.querySelector(#{selector.to_json}).getBoundingClientRect();return [r.top, r.bottom];})()")
  end

  def expect_bottomnav_shown
    expect(page).to have_css(".ba-bottomnav", visible: :visible)
  end

  def expect_bottomnav_hidden
    expect(page).to have_no_css(".ba-bottomnav", visible: :visible)
  end

  # ページ末尾までスクロールしたとき、selector の下端が下部ナビの上端より上にある(隠れていない)こと。
  def expect_not_covered_at_bottom(selector)
    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")
    _, bottom = rect(selector)
    nav_top, = rect(".ba-bottomnav")
    expect(bottom).to be <= nav_top
  end

  describe "スマホ: 下部ナビの表示と入力操作" do
    before do
      sign_in_as(owner)
      mobile!
    end

    it "文字入力の間だけ隠れ、セレクト・日付・ファイル選択・スタンプ選択の操作では表示されたままになる" do
      visit edit_business_project_path(project)

      find("#project_title").click
      expect_bottomnav_hidden
      # 実機と同じく、セレクトをタップ(フォーカス)してから選ぶ。
      find("#project_status").click
      find("#project_status").select("募集中")
      expect_bottomnav_shown

      find("#project_goal").click
      expect_bottomnav_hidden
      find("#project_deadline").click
      expect_bottomnav_shown

      find("#project_title").click
      expect_bottomnav_hidden
      page.execute_script("document.getElementById('image-input').focus()")
      expect_bottomnav_shown

      visit business_project_thread_path(project, ProjectThread.default_for(project))
      find(".business-composer__textarea").click
      expect_bottomnav_hidden
      find("[data-stamp-picker-toggle]").click
      expect(page).to have_css(".stamp-picker__panel", visible: :visible)
      expect_bottomnav_shown
    end

    it "ページ末尾の操作・エラーメッセージが固定ナビに隠れない" do
      visit business_project_thread_path(project, ProjectThread.default_for(project))
      expect_not_covered_at_bottom(".business-stamp-picker")

      visit edit_business_community_path(community)
      expect_not_covered_at_bottom("#plan-trial")

      fill_in "community_name", with: ""
      click_button "保存する"
      expect(page).to have_css(".ba-errors", visible: :visible)
      top, bottom = rect(".ba-errors")
      _, topbar_bottom = rect(".ba-topbar")
      nav_top, = rect(".ba-bottomnav")
      expect(top).to be >= topbar_bottom
      expect(bottom).to be <= nav_top
    end

    it "メニューは遷移後・戻る操作の後に閉じた状態になる" do
      visit business_community_path(community)
      find("#baMenuToggle").click
      expect(page).to have_css("#baMenuSheet", visible: :visible)
      within("#baMenuSheet") { click_link "プロフィール設定" }
      expect(page).to have_current_path(edit_business_customer_path(owner), wait: 10)
      expect(page).to have_no_css("#baMenuSheet", visible: :visible)
      expect(find("#baMenuToggle")["aria-expanded"]).to eq "false"
      expect(page.evaluate_script("document.body.classList.contains('ba-sheet-open')")).to eq false

      page.go_back
      expect(page).to have_current_path(business_community_path(community), wait: 10)
      expect(page).to have_no_css("#baMenuSheet", visible: :visible)
      expect(find("#baMenuToggle")["aria-expanded"]).to eq "false"
      expect_bottomnav_shown
    end
  end

  describe "共用画面・保存とキャンセルの導線" do
    before { sign_in_as(owner) }

    it "プロフィール設定: キャンセルでは保存せず、保存するとプロフィールへ戻ってお知らせが見える" do
      visit edit_business_customer_path(owner)
      fill_in "customer_name", with: "保存しない名前"
      click_link "キャンセル"
      expect(page).to have_current_path(business_customer_path(owner), wait: 10)
      expect(owner.reload.name).to eq "運営 確認ユーザー"

      visit edit_business_customer_path(owner)
      fill_in "customer_name", with: "保存した名前"
      click_button "更新する"
      expect(page).to have_current_path(business_customer_path(owner), wait: 10)
      expect(page).to have_css(".notifications", text: "更新しました", visible: :visible)
      expect(owner.reload.name).to eq "保存した名前"
    end

    it "プラン案内から契約プラン管理(#plan-management)へ移動でき、見出しが上部バーに隠れない" do
      member = create(:customer, domain_name: "business", onboarding_done: true)
      CommunityCustomer.create!(community: community, customer: member)
      Capybara.reset_sessions!
      sign_in_as(member)
      mobile!

      visit business_community_path(community)
      find(".ba-project-create-note a").click
      expect(page).to have_current_path(edit_business_customer_path(member), wait: 10)
      expect(page.evaluate_script("location.hash")).to eq "#plan-management"
      expect(page).to have_css("#plan-management .subscription-manager", visible: :visible)
      top, = rect("#plan-management-title")
      _, topbar_bottom = rect(".ba-topbar")
      expect(top).to be >= topbar_bottom
    end

    it "ログアウトするとドメイン共通のログイン画面へ移り、ログインし直すと Business の枠に戻る" do
      use_desktop_viewport
      within(".ba-sidenav") { click_button "ログアウト" }
      expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
      expect(page).to have_no_css(".ba-sidenav, .ba-bottomnav")

      sign_in_as(owner)
      expect(page).to have_css("body.ba-body .ba-home")
    end
  end
end
