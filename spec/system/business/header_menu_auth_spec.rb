require "rails_helper"

# Business(NAKAMA)ヘッダー右上のアカウントメニュー(ログイン / ログアウト)と通知ベルを実ブラウザで確認する。
RSpec.describe "Business ヘッダー: アカウントメニューと通知ベル", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:customer) { create(:customer, name: "NAKAMA確認ユーザー", domain_name: "business", onboarding_done: true) }

  let(:toggle_selector) { "#businessAccountMenuToggle" }
  let(:panel_selector) { ".business-account-menu__panel" }

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  # Business トップはスライダー(slick)の矢印が既存で数px はみ出すため、ヘッダー内の要素だけを測る。
  # 全画面オーバーレイの SP メニュー(position: fixed)と、閉じているドロップダウンは対象外。
  def header_overflow
    page.evaluate_script(<<~JS)
      (function () {
        var width = document.documentElement.clientWidth;
        var max = 0;
        document.querySelectorAll(".header_container *").forEach(function (el) {
          if (el.closest(".customer-menu-sp")) return;
          var rect = el.getBoundingClientRect();
          if (rect.width === 0 && rect.height === 0) return;
          max = Math.max(max, rect.right - width, -rect.left);
        });
        return Math.ceil(max);
      })()
    JS
  end

  # ロゴ・キャッチコピーと右上アイコン群が重なっていないこと。
  def header_items_overlap?
    page.evaluate_script(<<~JS)
      (function () {
        var logo = document.querySelector(".header_container .top-message").getBoundingClientRect();
        var utils = document.querySelector(".business-header-utils").children;
        for (var i = 0; i < utils.length; i++) {
          var r = utils[i].getBoundingClientRect();
          if (r.width === 0) continue;
          if (r.left < logo.right && r.right > logo.left && r.top < logo.bottom && r.bottom > logo.top) return true;
        }
        return false;
      })()
    JS
  end

  def sign_in_via_business_form
    visit new_business_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  def open_account_menu
    find(toggle_selector).click
    expect(page).to have_css(panel_selector, visible: :visible)
    expect(find(toggle_selector)["aria-expanded"]).to eq "true"
  end

  def expect_account_menu_closed
    expect(page).to have_no_css(panel_selector, visible: :visible)
    expect(find(toggle_selector)["aria-expanded"]).to eq "false"
  end

  def set_viewport(width)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: 900, deviceScaleFactor: 1, mobile: width < 600
    )
  end

  # 実際のタップに近い操作として、CDP のタッチ入力(touchStart → touchEnd)を要素の中心へ送る。
  # マウスのクリックとは別経路で、ブラウザがタップとして click を発生させる。
  def tap(element)
    x, y = page.evaluate_script(
      "(function(e){var r=e.getBoundingClientRect();return [r.left + r.width / 2, r.top + r.height / 2];})(arguments[0])", element
    )
    browser = page.driver.browser
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchStart", touchPoints: [{ x: x, y: y }])
    browser.execute_cdp("Input.dispatchTouchEvent", type: "touchEnd", touchPoints: [])
  end

  def open_sp_menu
    find("button#open").click
    expect(page).to have_css("#businessSpMenu.show", visible: :visible)
    expect(find("button#open", visible: :all)["aria-expanded"]).to eq "true"
  end

  def expect_sp_menu_closed
    expect(page).to have_no_css("#businessSpMenu.show")
    expect(find("button#open")["aria-expanded"]).to eq "false"
  end

  def active_element_text
    page.evaluate_script("document.activeElement.textContent.trim()")
  end

  context "未ログイン" do
    it "PC: 汎用アイコンのドロップダウンからログイン画面へ進め、ベルは出ない" do
      visit business_root_path
      set_viewport(1280)
      visit business_root_path

      expect(page).to have_no_css(".business-header-bell")
      expect(page).to have_no_css("button#open", visible: :visible)
      within(toggle_selector) { expect(page).to have_css("i.fa-circle-user") }
      expect(header_overflow).to be <= 0
      expect(header_items_overlap?).to eq false

      open_account_menu
      within(panel_selector) do
        expect(page).to have_no_button("ログアウト")
        click_link "ログイン"
      end

      expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
    end

    it "スマホ: 汎用アイコンはドロップダウンを開かずログイン画面へのリンクになる" do
      visit business_root_path
      set_viewport(375)
      visit business_root_path

      expect(page).to have_no_css(".business-header-bell")
      expect(page).to have_no_css(toggle_selector, visible: :visible)
      expect(header_overflow).to be <= 0
      expect(header_items_overlap?).to eq false

      find("a.business-account-link").click
      expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
    end

    it "スマホ: ☰からログイン・新規登録へ進める" do
      visit business_root_path
      set_viewport(375)
      visit business_root_path

      open_sp_menu
      within("#businessSpMenu") do
        expect(page).to have_no_button("ログアウト")
        expect(page).to have_link("新規登録", href: new_business_customer_registration_path)
      end
      within("#businessSpMenu") { click_link "ログイン" }
      expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
    end

    it "外側クリック・Escape で閉じ、キーボードだけで開いて項目へ移動できる" do
      visit business_root_path
      set_viewport(1280)
      visit business_root_path

      open_account_menu
      find(".top-message h1").click
      expect_account_menu_closed

      open_account_menu
      find(toggle_selector).send_keys(:escape)
      expect_account_menu_closed

      find(toggle_selector).send_keys(:enter)
      expect(page).to have_css(panel_selector, visible: :visible)
      find(toggle_selector).send_keys(:down)
      expect(page.evaluate_script("document.activeElement.textContent.trim()")).to eq "ログイン"
      page.send_keys(:escape)
      expect_account_menu_closed
      expect(page.evaluate_script("document.activeElement.id")).to eq "businessAccountMenuToggle"
    end
  end

  context "ログイン済み" do
    before do
      other = create(:customer, domain_name: "business")
      Notification.create!(visitor: other, visited: customer, action: "follow", checked: false)
    end

    [375, 768, 1280].each do |width|
      it "幅#{width}px: ベル・アイコン(・☰)が重ならず並び、メニューがはみ出さない" do
        sign_in_via_business_form
        set_viewport(width)
        # トップはスライダー(slick)の矢印が既存で数px はみ出すため、ページ全体の横はみ出しは別ページで測る。
        visit business_communities_path

        expect(page).to have_css(".business-header-bell", visible: :visible)
        expect(page).to have_css(".business-header-bell__badge", text: "1", visible: :visible)
        expect(header_overflow).to be <= 0
        expect(horizontal_overflow).to be <= 0
        expect(header_items_overlap?).to eq false

        if width < 600
          expect(page).to have_css("a.business-account-link", visible: :visible)
          expect(page).to have_no_css(toggle_selector, visible: :visible)
          open_sp_menu
          expect(horizontal_overflow).to be <= 0
        else
          expect(page).to have_no_css("button#open", visible: :visible)
          open_account_menu
          panel_rect = page.evaluate_script(
            "(function(){var r=document.querySelector('#{panel_selector}').getBoundingClientRect();return [r.left, r.right, document.documentElement.clientWidth];})()"
          )
          expect(panel_rect[0]).to be >= 0
          expect(panel_rect[1]).to be <= panel_rect[2]
        end
        page.save_screenshot(Rails.root.join("tmp/screenshots/business_header_#{width}.png").to_s)
      end
    end

    it "ベルから通知一覧へ移動でき、既読後はバッジが消える" do
      sign_in_via_business_form
      set_viewport(375)
      visit business_communities_path

      find(".business-header-bell").click
      expect(page).to have_current_path(business_notifications_path, wait: 10)
      expect(page).to have_css(".notification-card", text: "フォローしました")
      expect(page).to have_css(".business-header-bell", visible: :visible)
      expect(page).to have_no_css(".business-header-bell__badge")
    end

    it "スマホ: アイコンは自分のプロフィールへのリンクになる" do
      sign_in_via_business_form
      set_viewport(375)
      visit business_communities_path

      find("a.business-account-link").click
      expect(page).to have_current_path(business_customer_path(customer), wait: 10)
    end

    it "PC: アイコンのドロップダウンからログアウトできる" do
      sign_in_via_business_form
      set_viewport(1280)
      visit business_communities_path

      open_account_menu
      within(panel_selector) do
        expect(page).to have_link("プロフィール", href: business_customer_path(customer))
        expect(page).to have_no_link("ログイン")
        click_button "ログアウト"
      end

      expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
      visit business_root_path
      expect(page).to have_no_css(".business-header-bell")
    end

    it "スマホ: ☰に移動項目とアカウント項目がまとまり、そこからログアウトできる" do
      sign_in_via_business_form
      set_viewport(375)
      visit business_communities_path

      open_sp_menu
      within("#businessSpMenu") do
        expect(page).to have_link("タイムライン")
        expect(page).to have_link("プロフィール", href: business_customer_path(customer))
        expect(page).to have_link("プロフィール設定", href: edit_business_customer_path(customer))
        expect(page).to have_link(href: business_notifications_path, text: /通知/)
        expect(page).to have_no_link("ログイン")
        expect(page).to have_button("ログアウト")
      end
      within("#businessSpMenu") { click_button "ログアウト" }

      expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
    end

    it "スマホ: ☰から移動でき、閉じる・Escape・背景クリックで閉じてフォーカスが☰に戻る" do
      sign_in_via_business_form
      set_viewport(375)
      visit business_communities_path

      open_sp_menu
      expect(active_element_text).to eq "閉じる"
      find("#businessSpMenu #close").click
      expect_sp_menu_closed
      expect(page.evaluate_script("document.activeElement.id")).to eq "open"

      # キーボードだけで開閉する(Enter で開き、Escape で閉じて☰へ戻る)
      find("button#open").send_keys(:enter)
      expect(page).to have_css("#businessSpMenu.show", visible: :visible)
      expect(find("button#open", visible: :all)["aria-expanded"]).to eq "true"
      page.send_keys(:escape)
      expect_sp_menu_closed
      expect(page.evaluate_script("document.activeElement.id")).to eq "open"

      # 開いている間、Tab はメニュー内で循環する(先頭で Shift+Tab → 末尾のログアウト、末尾で Tab → 先頭)
      open_sp_menu
      page.send_keys(%i[shift tab])
      expect(active_element_text).to eq "ログアウト"
      page.send_keys(:tab)
      expect(active_element_text).to eq "閉じる"

      # 項目以外(背景の左上の余白)のクリックで閉じる。Capybara の offset は要素の中心からの距離。
      menu = find("#businessSpMenu")
      width, height = page.evaluate_script("(function(e){var r=e.getBoundingClientRect();return [r.width, r.height];})(arguments[0])", menu)
      menu.click(x: 8 - (width / 2), y: 8 - (height / 2))
      expect_sp_menu_closed

      open_sp_menu
      within("#businessSpMenu") { click_link "プロジェクト" }
      expect(page).to have_current_path(business_projects_path, wait: 10)
      expect_sp_menu_closed
    end
  end

  context "スマホのタップ操作(CDP のタッチ入力)" do
    before do
      other = create(:customer, domain_name: "business")
      Notification.create!(visitor: other, visited: customer, action: "follow", checked: false)
    end

    it "☰・閉じる・メニュー内リンク・ユーザーアイコン・通知ベルをタップで操作できる" do
      sign_in_via_business_form
      set_viewport(375)
      page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
      visit business_communities_path

      tap(find("button#open"))
      expect(page).to have_css("#businessSpMenu.show", visible: :visible)
      expect(find("button#open", visible: :all)["aria-expanded"]).to eq "true"

      tap(find("#businessSpMenu #close"))
      expect_sp_menu_closed

      tap(find("button#open"))
      expect(page).to have_css("#businessSpMenu.show", visible: :visible)
      tap(find("#businessSpMenu a", text: "プロジェクト"))
      expect(page).to have_current_path(business_projects_path, wait: 10)
      expect_sp_menu_closed

      tap(find("a.business-account-link"))
      expect(page).to have_current_path(business_customer_path(customer), wait: 10)

      tap(find(".business-header-bell"))
      expect(page).to have_current_path(business_notifications_path, wait: 10)
    ensure
      page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    end
  end

  context "トップのスライダー" do
    [375, 768, 1280].each do |width|
      it "幅#{width}px: 矢印が画面内に収まり、ページ全体が横にはみ出さない" do
        visit business_root_path
        set_viewport(width)
        visit business_root_path
        expect(page).to have_css(".business-top-slider.slick-initialized .slick-next", visible: :visible)

        arrows = page.evaluate_script(<<~JS)
          (function () {
            var width = document.documentElement.clientWidth;
            return Array.from(document.querySelectorAll(".business-top-slider .slick-arrow")).map(function (el) {
              var r = el.getBoundingClientRect();
              return r.left >= 0 && r.right <= width;
            });
          })()
        JS
        expect(arrows).to eq [true, true]
        expect(horizontal_overflow).to be <= 0
        expect(page.evaluate_script("getComputedStyle(document.body).overflowX")).to eq "visible"
        page.execute_script("document.querySelector('.business-top-slider').scrollIntoView()")
        page.save_screenshot(Rails.root.join("tmp/screenshots/business_top_slider_#{width}.png").to_s)
      end
    end
  end

  context "コミュニティの通常画面・編集画面(お試し設定カード)" do
    let(:community) { create(:community, owner: customer, domain: business_domain, plan_restrictions_waived: true) }

    before { CommunityCustomer.create!(community: community, customer: customer) }

    it "スマホ幅で横スクロールせず、通常画面にお試し表示、編集画面に設定の状態が見える" do
      sign_in_via_business_form
      set_viewport(375)
      visit business_community_path(community)

      expect(page).to have_css(".plan-trial-badge", visible: :visible)
      expect(page).to have_no_css("#plan-trial")
      expect(horizontal_overflow).to be <= 0

      visit edit_business_community_path(community)
      expect(page).to have_css("#plan-trial", text: "現在：ON（無料お試し中）", visible: :visible)
      expect(horizontal_overflow).to be <= 0
    end
  end
end
