require "rails_helper"

# Business(NAKAMA)のログイン後の枠(左ナビ・下部ナビ・メニュー)を実ブラウザで確認する。ログイン前の紹介ページは landing_spec.rb。
RSpec.describe "Business のログイン後のナビゲーション", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:customer) { create(:customer, name: "NAKAMA確認ユーザー", domain_name: "business", onboarding_done: true) }

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  def sign_in_via_business_form
    visit new_business_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_root_path, wait: 10)
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

  # タップ操作の spec は全体実行時に一度だけ原因不明で落ちたことがあるため、落ちたときに
  # 「どの操作の途中だったか」を残す。判定・待機は変えず、記録したら元の例外をそのまま投げ直す。
  # パスワード・Cookie・URL のクエリは記録しない。
  def tap_js_error_key
    "baTapDiagnosticsJsErrors"
  end

  def start_tap_diagnostics
    @tap_steps_done = []
    # ドライバ全体のログ設定は変えず、このブラウザで開くページにだけエラー収集を仕込む。
    # 画面遷移しても残るよう sessionStorage に溜める(直近 20 件)。
    @tap_error_script = page.driver.browser.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: <<~JS)["identifier"]
      (function () {
        function push(text) {
          try {
            var list = JSON.parse(sessionStorage.getItem("#{tap_js_error_key}") || "[]");
            list.push(location.pathname + " " + text);
            sessionStorage.setItem("#{tap_js_error_key}", JSON.stringify(list.slice(-20)));
          } catch (e) {}
        }
        window.addEventListener("error", function (e) {
          push(e.message + " (" + String(e.filename || "").split("?")[0] + ":" + e.lineno + ")");
        });
        window.addEventListener("unhandledrejection", function (e) {
          push("unhandledrejection: " + String((e.reason && e.reason.message) || e.reason));
        });
      })();
    JS
  end

  def stop_tap_diagnostics
    return unless @tap_error_script

    page.driver.browser.execute_cdp("Page.removeScriptToEvaluateOnNewDocument", identifier: @tap_error_script)
  end

  def tap_step(name)
    yield
    @tap_steps_done << name
  rescue StandardError, RSpec::Expectations::ExpectationNotMetError => e
    record_tap_failure(name, e)
    raise
  end

  def record_tap_failure(failed_step, error)
    url = URI.parse(page.current_url)
    size = page.evaluate_script("[window.innerWidth, window.innerHeight]")
    js_errors = JSON.parse(page.evaluate_script("sessionStorage.getItem('#{tap_js_error_key}')") || "[]")
    base = Rails.root.join("tmp/screenshots/tap_diagnostics_#{Time.now.strftime('%Y%m%d%H%M%S')}_#{SecureRandom.hex(3)}")
    page.save_screenshot("#{base}.png")

    report = <<~TEXT
      [タップ操作の診断記録]
      完了した操作: #{@tap_steps_done.join(' → ').presence || '(なし)'}
      最後に完了した操作: #{@tap_steps_done.last || '(なし)'}
      失敗した操作: #{failed_step}
      例外: #{error.class}: #{error.message.lines.first.to_s.strip}
      現在の URL: #{url.path}
      画面サイズ: #{size.join('x')}
      JavaScript エラー: #{js_errors.presence&.join(' / ') || '(なし)'}
      スクリーンショット: #{base}.png
    TEXT
    File.write("#{base}.txt", report)
    RSpec.configuration.reporter.message(report)
  rescue StandardError => e
    # 記録に失敗しても、元の失敗を上書きしない。
    RSpec.configuration.reporter.message("[タップ操作の診断記録] 記録できませんでした: #{e.class}: #{e.message}")
  end

  def active_element_text
    page.evaluate_script("document.activeElement.textContent.trim()")
  end

  # ログイン後は Business の枠(layouts/business): PC は左ナビ、SP・タブレットは下部ナビ + メニューシート。
  context "ログイン済み(Business の枠のナビゲーション)" do
    before do
      other = create(:customer, domain_name: "business")
      Notification.create!(visitor: other, visited: customer, action: "follow", checked: false)
    end

    def sheet_open?
      page.evaluate_script("!document.getElementById('baMenuSheet').hidden")
    end

    def open_sheet
      find("button#baMenuToggle").click
      expect(page).to have_css("#baMenuSheet", visible: :visible)
      expect(find("button#baMenuToggle")["aria-expanded"]).to eq "true"
    end

    def expect_sheet_closed
      expect(page).to have_no_css("#baMenuSheet", visible: :visible)
      expect(find("button#baMenuToggle")["aria-expanded"]).to eq "false"
    end

    { 375 => :bottom, 768 => :bottom, 1024 => :rail, 1280 => :side }.each do |width, mode|
      it "幅#{width}px: #{mode == :bottom ? '下部ナビ' : '左ナビ'}が表示され、未読バッジ・現在地が分かり、はみ出さない" do
        sign_in_via_business_form
        set_viewport(width)
        visit business_communities_path

        nav = mode == :bottom ? ".ba-bottomnav" : ".ba-sidenav"
        hidden = mode == :bottom ? ".ba-sidenav" : ".ba-bottomnav"
        expect(page).to have_css(nav, visible: :visible)
        expect(page).to have_no_css(hidden, visible: :visible)
        expect(page).to have_css("#{nav} .ba-nav-badge", text: "1", visible: :visible)
        expect(find("#{nav} a[aria-current='page']")["href"]).to end_with(business_communities_path)
        expect(horizontal_overflow).to be <= 0

        # 本文の最後の要素が下部ナビ・左ナビに隠れない。
        page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight)")
        overlap = page.evaluate_script(<<~JS)
          (function () {
            var main = document.querySelector(".ba-main").getBoundingClientRect();
            var nav = document.querySelector("#{nav}").getBoundingClientRect();
            var last = Array.from(document.querySelectorAll(".ba-main *")).filter(function (el) {
              var r = el.getBoundingClientRect(); return r.height > 0;
            }).pop().getBoundingClientRect();
            if ("#{mode}" === "bottom") return last.bottom > nav.top;
            return main.left < nav.right;
          })()
        JS
        expect(overlap).to eq false
        page.save_screenshot(Rails.root.join("tmp/screenshots/business_nav_#{width}.png").to_s)
      end
    end

    it "通知から通知一覧へ移動でき、既読後はバッジが消える" do
      sign_in_via_business_form
      set_viewport(375)
      visit business_communities_path

      find(".ba-bottomnav a[href='#{business_notifications_path}']").click
      expect(page).to have_current_path(business_notifications_path, wait: 10)
      expect(page).to have_css(".ba-notification.is-unread", text: "フォローしました")
      expect(page).to have_no_css(".ba-nav-badge")
    end

    it "PC: 左ナビからプロフィールへ移動でき、ログアウトできる" do
      sign_in_via_business_form
      set_viewport(1280)
      visit business_communities_path

      find(".ba-sidenav__profile").click
      expect(page).to have_current_path(business_customer_path(customer), wait: 10)
      expect(page).to have_css(".ba-sidenav__profile[aria-current='page']")

      within(".ba-sidenav") { click_button "ログアウト" }
      expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
      visit business_root_path
      expect(page).to have_no_css(".ba-sidenav")
      expect(page).to have_css(".ba-lp-hero")
    end

    it "スマホ: メニューにタイムライン・投稿・アカウント項目がまとまり、そこからログアウトできる" do
      sign_in_via_business_form
      set_viewport(375)
      visit business_communities_path

      open_sheet
      within("#baMenuSheet") do
        expect(page).to have_link("タイムライン")
        expect(page).to have_link(href: business_customer_path(customer))
        expect(page).to have_link("プロフィール設定", href: edit_business_customer_path(customer))
        expect(page).to have_no_link("ログイン")
        click_button "ログアウト"
      end
      expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
    end

    it "スマホ: メニューは閉じる・Escape・背景で閉じてフォーカスが戻り、開いている間は Tab が中で循環する" do
      sign_in_via_business_form
      set_viewport(375)
      visit business_communities_path

      open_sheet
      expect(active_element_text).to eq "閉じる"
      find("#baMenuSheet .ba-sheet__close").click
      expect_sheet_closed
      expect(page.evaluate_script("document.activeElement.id")).to eq "baMenuToggle"

      find("button#baMenuToggle").send_keys(:enter)
      expect(page).to have_css("#baMenuSheet", visible: :visible)
      page.send_keys(:escape)
      expect_sheet_closed
      expect(page.evaluate_script("document.activeElement.id")).to eq "baMenuToggle"

      open_sheet
      page.send_keys(%i[shift tab])
      expect(active_element_text).to eq "ログアウト"
      page.send_keys(:tab)
      expect(active_element_text).to eq "閉じる"

      # 上部の背景(シートの外)をクリックすると閉じる。
      page.driver.browser.action.move_to_location(20, 40).click.perform
      expect_sheet_closed

      open_sheet
      # タイムラインは MySQL 専用の並び替えを使うため(テストは SQLite)、メニュー内の別項目で遷移を確かめる。
      within("#baMenuSheet") { click_link "プロフィール設定" }
      expect(page).to have_current_path(edit_business_customer_path(customer), wait: 10)
      expect(page).to have_css("button#baMenuToggle.is-current")
    end

    it "スマホ: スレッドの入力中は下部ナビを隠し、入力欄・送信ボタンと重ねない" do
      community = create(:community, owner: customer, domain: business_domain)
      CommunityCustomer.create!(community: community, customer: customer)
      project = Project.create!(community: community, customer: customer, title: "入力確認")
      sign_in_via_business_form
      set_viewport(375)
      visit business_project_thread_path(project, ProjectThread.default_for(project))

      expect(page).to have_css(".ba-bottomnav", visible: :visible)
      find(".business-composer__textarea").click
      expect(page).to have_no_css(".ba-bottomnav", visible: :visible)
      submit_bottom = page.evaluate_script("document.querySelector('.business-composer__submit').getBoundingClientRect().bottom")
      expect(submit_bottom).to be > 0

      find(".ba-thread-header").click
      expect(page).to have_css(".ba-bottomnav", visible: :visible)
    end
  end

  context "スマホのタップ操作(CDP のタッチ入力)" do
    before do
      other = create(:customer, domain_name: "business")
      Notification.create!(visitor: other, visited: customer, action: "follow", checked: false)
    end

    it "下部ナビ・メニュー・閉じる・メニュー内リンクをタップで操作できる" do
      start_tap_diagnostics
      tap_step("ログイン") { sign_in_via_business_form }
      tap_step("幅375px・タッチ入力を有効化") do
        set_viewport(375)
        page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: true, maxTouchPoints: 1)
      end
      tap_step("コミュニティ一覧を開く") { visit business_communities_path }

      tap_step("メニューを開く") do
        tap(find("button#baMenuToggle"))
        expect(page).to have_css("#baMenuSheet", visible: :visible)
      end
      tap_step("閉じるで閉じる") do
        tap(find("#baMenuSheet .ba-sheet__close"))
        expect(page).to have_no_css("#baMenuSheet", visible: :visible)
      end

      tap_step("メニューを再度開く") { tap(find("button#baMenuToggle")) }
      tap_step("メニューのプロフィール設定へ移動") do
        tap(find("#baMenuSheet a", text: "プロフィール設定"))
        expect(page).to have_current_path(edit_business_customer_path(customer), wait: 10)
        # Turbolinks は新しい画面を描画する前に URL を変える。前の画面のシートが開いたまま次をタップすると、
        # 下部ナビと同じ位置にあるシートの「ログアウト」に当たるため、新しい画面の表示を待つ。
        expect(page).to have_css("button#baMenuToggle.is-current")
        expect(page).to have_no_css("#baMenuSheet", visible: :visible)
      end

      tap_step("下部ナビのプロジェクトへ移動") do
        tap(find(".ba-bottomnav a", text: "プロジェクト"))
        expect(page).to have_current_path(business_projects_path, wait: 10)
      end

      tap_step("下部ナビの通知へ移動") do
        tap(find(".ba-bottomnav a[href='#{business_notifications_path}']"))
        expect(page).to have_current_path(business_notifications_path, wait: 10)
      end

      tap_step("下部ナビのホームへ移動") do
        tap(find(".ba-bottomnav a", text: "ホーム"))
        expect(page).to have_current_path(business_root_path, wait: 10)
      end
    ensure
      stop_tap_diagnostics
      page.driver.browser.execute_cdp("Emulation.setTouchEmulationEnabled", enabled: false)
    end
  end

  context "コミュニティの通常画面・編集画面(お試し設定カード)" do
    let(:community) { create(:community, owner: customer, domain: business_domain, plan_restrictions_waived: true) }

    before { CommunityCustomer.create!(community: community, customer: customer) }

    it "スマホ幅で横スクロールせず、通常画面にお試し表示、編集画面に設定の状態が見える" do
      sign_in_via_business_form
      set_viewport(375)
      visit business_community_path(community)

      expect(page).to have_css(".ba-trial-badge", visible: :visible)
      expect(page).to have_no_css("#plan-trial")
      expect(horizontal_overflow).to be <= 0

      visit edit_business_community_path(community)
      expect(page).to have_css("#plan-trial", text: "現在：ON（無料お試し中）", visible: :visible)
      expect(horizontal_overflow).to be <= 0
    end
  end
end
