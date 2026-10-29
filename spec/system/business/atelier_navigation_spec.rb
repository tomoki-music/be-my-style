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

  describe "スマホ: メニューから画面を移る間の操作" do
    let(:gate) { Queue.new }

    before do
      sign_in_as(owner)
      mobile!
    end

    after { page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false) }

    # プロフィール設定(customers#edit)の応答を、テストが gate を開けるまで止めて「遅い画面遷移」を再現する。
    # @fail_profile_settings を立てると、止めた後にエラー画面(500)を返す。
    def hold_profile_settings
      community_path = business_community_path(community)
      allow_any_instance_of(Business::CustomersController).to receive(:edit).and_wrap_original do |original, *args|
        gate.pop
        if @fail_profile_settings
          html = %(<p>読み込みに失敗しました</p><a href="#{community_path}" data-turbolinks="false">コミュニティへ戻る</a>).html_safe
          original.receiver.send(:render, html: html, status: :internal_server_error)
        else
          original.call(*args)
        end
      end
    end

    def enable_touch!
      page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
    end

    def center_of(selector)
      page.evaluate_script("(function(){var r=document.querySelector(#{selector.to_json}).getBoundingClientRect();return [r.left + r.width / 2, r.top + r.height / 2];})()")
    end

    # CDP のタッチ入力(touchStart → touchEnd)を指定した座標へ送る。
    def tap_at(x, y)
      browser = page.driver.browser
      browser.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: [{ x: x, y: y }])
      browser.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
    end

    # Turbolinks は描画前に URL を変えるため、今の body に印を付け、それが消えたことで描画の完了を確かめる。
    def mark_current_body(token)
      page.execute_script("document.body.dataset.navToken = #{token.to_json}")
    end

    def expect_body_replaced(token)
      expect(page).to have_no_css("body[data-nav-token='#{token}']", wait: 10)
    end

    # シート・背景スクロール・操作可能な状態が元どおりで、メニューを開き直して Escape で閉じるとフォーカスが戻ること。
    def expect_menu_usable
      expect(page).to have_no_css("body.ba-nav-pending")
      expect(page).to have_no_css("body.ba-sheet-open")
      expect(page).to have_no_css("#baMenuSheet", visible: :visible)
      find("#baMenuToggle").click
      expect(page).to have_css("#baMenuSheet", visible: :visible)
      find("#baMenuSheet .ba-sheet__close").send_keys(:escape)
      expect(page).to have_no_css("#baMenuSheet", visible: :visible)
      expect(page.evaluate_script("document.activeElement.id")).to eq "baMenuToggle"
    end

    it "メニューのリンクを選ぶとすぐ閉じ、表示が切り替わるまでの連続タップはログアウトや別の画面へ通らない" do
      hold_profile_settings
      enable_touch!
      visit business_community_path(community)
      mark_current_body("community")

      find("#baMenuToggle").click
      expect(page).to have_css("#baMenuSheet", visible: :visible)
      logout_point = center_of("#baMenuSheet .ba-sheet__logout")
      projects_point = center_of(".ba-bottomnav a[href='#{business_projects_path}']")
      tap_at(*center_of("#baMenuSheet .ba-sheet__link[href='#{edit_business_customer_path(owner)}']"))

      # サーバーの応答を止めている間(読み込み中)
      expect(page).to have_no_css("#baMenuSheet", visible: :visible)
      expect(page).to have_css("body.ba-nav-pending[data-nav-token='community']")
      expect(page.evaluate_script("document.body.classList.contains('ba-sheet-open')")).to eq false
      expect(page.evaluate_script("document.activeElement.id")).not_to eq "baMenuToggle"
      # 開いていたときの「ログアウト」の位置と、下部ナビ「プロジェクト」の位置を続けてタップする。
      tap_at(*logout_point)
      tap_at(*projects_point)

      gate << true
      expect_body_replaced("community")
      expect(page).to have_current_path(edit_business_customer_path(owner))
      expect(page).to have_css("button#baMenuToggle.is-current")
      expect(page).to have_field("customer_name")
      expect_menu_usable
    ensure
      gate << true
    end

    it "移った後の戻る・進む・同じ画面へのリンクでも、閉じた状態に戻り、メニューと Escape・フォーカスが元どおり動く" do
      visit business_community_path(community)
      mark_current_body("community")
      find("#baMenuToggle").click
      within("#baMenuSheet") { click_link "プロフィール設定" }
      expect_body_replaced("community")
      expect(page).to have_css("button#baMenuToggle.is-current")
      expect_menu_usable

      mark_current_body("settings")
      page.go_back
      expect(page).to have_current_path(business_community_path(community), wait: 10)
      expect_body_replaced("settings")
      expect_menu_usable

      mark_current_body("community-again")
      page.go_forward
      expect(page).to have_current_path(edit_business_customer_path(owner), wait: 10)
      expect_body_replaced("community-again")
      expect_menu_usable

      # 今いる画面と同じリンクをキーボードで選ぶ。
      mark_current_body("settings-again")
      find("#baMenuToggle").click
      find("#baMenuSheet .ba-sheet__link[href='#{edit_business_customer_path(owner)}']").send_keys(:enter)
      expect_body_replaced("settings-again")
      expect(page).to have_current_path(edit_business_customer_path(owner))
      expect_menu_usable
    end

    it "読み込み中に戻る操作をしても、読み込みが失敗しても、操作できない状態が残らない" do
      hold_profile_settings
      visit business_community_path(community)
      find("#baMenuToggle").click
      within("#baMenuSheet") { click_link "プロフィール設定" }
      expect(page).to have_css("body.ba-nav-pending")

      mark_current_body("pending")
      page.go_back
      expect(page).to have_current_path(business_community_path(community), wait: 10)
      expect_body_replaced("pending")
      expect_menu_usable
      gate << true

      @fail_profile_settings = true
      mark_current_body("before-failure")
      find("#baMenuToggle").click
      within("#baMenuSheet") { click_link "プロフィール設定" }
      expect(page).to have_css("body.ba-nav-pending")
      gate << true
      expect_body_replaced("before-failure")
      expect(page).to have_text("読み込みに失敗しました")
      expect(page).to have_no_css("body.ba-nav-pending")
      # エラー画面のリンクを実際に押せる(覆いが残っていない)。
      click_link "コミュニティへ戻る"
      expect(page).to have_current_path(business_community_path(community), wait: 10)
      expect(page).to have_css("body.ba-body")
      expect_menu_usable
    ensure
      2.times { gate << true }
    end

    it "メニューの「ログアウト」をタップしたときは、ログアウトする" do
      enable_touch!
      visit business_community_path(community)
      find("#baMenuToggle").click
      expect(page).to have_css("#baMenuSheet", visible: :visible)
      tap_at(*center_of("#baMenuSheet .ba-sheet__logout"))
      expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
      expect(page).to have_no_css(".ba-bottomnav")
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
