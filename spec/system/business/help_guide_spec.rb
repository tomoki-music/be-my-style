require "rails_helper"

# 使い方(/business/help)・利用ガイド・タイムラインを実ブラウザで確認する。データはすべて架空。
RSpec.describe "Business の使い方・利用ガイド・タイムライン", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:customer) { create(:customer, domain_name: "business", onboarding_done: true, name: "青山 葵") }
  let(:author) { create(:customer, domain_name: "business", onboarding_done: true, name: "森 湊") }


  def set_viewport(width, height = 900)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 600
    )
  end

  def visit_at(path, width)
    visit path
    set_viewport(width)
    visit path
  end

  def sign_in_as(target)
    visit new_business_customer_session_path
    fill_in "customer_email", with: target.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_current_path(business_root_path, wait: 10)
  end

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  # 表示中のイラストがすべて読み込まれ、縦横比が属性どおり(レイアウトずれが無い)こと。
  def expect_illustrations_loaded
    page.execute_script("document.querySelectorAll('img.ba-illust').forEach(function(img){ img.loading = 'eager'; })")
    expect(page).to have_css("img.ba-illust", visible: :all)
    Timeout.timeout(10) do
      sleep 0.1 until page.evaluate_script("Array.from(document.querySelectorAll('img.ba-illust')).every(function(img){ return img.complete; })")
    end
    images = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('img.ba-illust')).map(function (img) {
        var r = img.getBoundingClientRect();
        return { natural: img.naturalWidth, ratio: r.height ? r.width / r.height : 0,
                 attr: img.getAttribute('width') / img.getAttribute('height'), shown: r.width > 0 };
      })
    JS
    images.select { |img| img["shown"] }.each do |img|
      expect(img["natural"]).to be > 0
      expect(img["ratio"]).to be_within(0.03).of(img["attr"])
    end
  end

  # 資料用にページ全体を撮る(撮る間だけ表示の高さを本文の高さに合わせる)。
  def shot(name)
    width = page.evaluate_script("window.innerWidth")
    height = page.evaluate_script("document.documentElement.scrollHeight")
    set_viewport(width, [height, 900].max)
    # 表示の高さを変えると画像が描き直されるため、デコードが終わってから撮る(decoding="async" のため)。
    # 遅延読み込みの画像も先に読み込ませる。デコードが終わらない画像があっても 3 秒で撮る。
    page.evaluate_async_script(<<~JS)
      var done = arguments[arguments.length - 1];
      document.querySelectorAll("img").forEach(function (img) { img.loading = "eager"; });
      var decoded = Promise.all(Array.from(document.images).map(function (img) { return img.decode().catch(function () {}); }));
      Promise.race([decoded, new Promise(function (resolve) { setTimeout(resolve, 3000); })])
        .then(function () { requestAnimationFrame(function () { requestAnimationFrame(done); }); });
    JS
    page.save_screenshot(Rails.root.join("tmp/screenshots/#{name}.png").to_s)
    set_viewport(width)
  end

  [320, 375, 768, 1280].each do |width|
    it "幅#{width}px: ログイン前の使い方・トップが横にはみ出さず、イラストが読み込まれる" do
      visit_at(business_help_path, width)
      expect(page).to have_css("body.ba-lp h1", text: "NAKAMAの使い方")
      expect(horizontal_overflow).to be <= 0
      expect(page).to have_no_css("img.ba-illust")
      shot("help_guest_#{width}")

      visit business_root_path
      expect(page).to have_css(".ba-flow__step", count: 3)
      expect(horizontal_overflow).to be <= 0
      # 絵は画面外で遅延読み込みされる。読み込み前から縦横比どおりの場所が確保され、読み込み後も高さが変わらないこと。
      before = page.evaluate_script("(function(){var i=document.querySelector('.ba-lp-flow img');return {loaded: i.complete && i.naturalWidth > 0, h: document.querySelector('.ba-lp-flow').getBoundingClientRect().height};})()")
      expect_illustrations_loaded
      after = page.evaluate_script("document.querySelector('.ba-lp-flow').getBoundingClientRect().height")
      expect(after).to be_within(1).of(before["h"])
      expect(page).to have_css(".ba-lp-hero .ba-lp-actions__primary", visible: :visible)
      shot("landing_#{width}")
    end

    it "幅#{width}px: ログイン後のホーム(所属0件・所属あり)・使い方・タイムラインが横にはみ出さない" do
      sign_in_as(customer)
      set_viewport(width)

      visit business_root_path
      expect(page).to have_css(".ba-empty--guide", text: "まずはコミュニティに参加しましょう")
      expect(horizontal_overflow).to be <= 0
      expect_illustrations_loaded
      # 絵は小さく添えるだけで、「コミュニティを探す」は最初の画面に収まる。
      expect(page.evaluate_script("document.querySelector('.ba-empty--guide img').getBoundingClientRect().width")).to be <= 200
      expect(page.evaluate_script("document.querySelector('.ba-empty--guide .ba-btn--primary').getBoundingClientRect().bottom")).to be <= 900
      shot("home_empty_#{width}")

      community = create(:community, name: "地域企画ラボ", domain: business_domain)
      CommunityCustomer.create!(community: community, customer: customer)
      visit business_root_path
      expect(page).to have_css(".ba-home-guide", text: "利用ガイド")
      expect(horizontal_overflow).to be <= 0
      expect_illustrations_loaded if width >= 360
      guide_img = page.evaluate_script("(function(){var r=document.querySelector('.ba-home-guide img').getBoundingClientRect();return r.width;})()")
      expect(guide_img).to be <= 132
      shot("home_guide_#{width}")

      visit business_help_path
      expect(page).to have_css("body.ba-body h1", text: "NAKAMAの使い方")
      expect(horizontal_overflow).to be <= 0
      shot("help_member_#{width}")

      Post.create!(customer: author, title: "商店街イベントの振り返り", body: "来場者アンケートから分かったことを共有します。", category: "free_post", tag_list: ["イベント"])
      Post.create!(customer: author, title: "提案資料の型", body: "最初の1枚で課題を言い切ると伝わりやすかったです。", category: "free_post")
      visit business_timeline_path
      expect(page).to have_css(".ba-post-card", count: 2)
      expect(page).to have_css(".ba-visibility", text: "ログインしている全員が見られます")
      expect(horizontal_overflow).to be <= 0
      # タブは3つとも横スクロールせずに見える。
      tabs = page.evaluate_script("(function(){var n=document.querySelector('.ba-timeline__tabs');return [n.scrollWidth, n.clientWidth];})()")
      expect(tabs[0]).to be <= tabs[1]
      shot("timeline_#{width}")
    end
  end

  it "絵の読み込みを止めても、縦横比どおりの場所が先に確保され、読み込み後も周りが動かない" do
    [375, 1280].each do |width|
      page.driver.browser.execute_cdp("Network.enable")
      page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: ["*business/illustrations/*"])
      visit_at(business_root_path, width)
      page.execute_script("document.querySelector('.ba-lp-flow img').loading = 'eager'")
      blocked = page.evaluate_script(<<~JS)
        (function () {
          var img = document.querySelector('.ba-lp-flow img'), r = img.getBoundingClientRect();
          return { loaded: img.naturalWidth > 0, ratio: r.width / r.height, flow: document.querySelector('.ba-lp-flow').getBoundingClientRect().height };
        })()
      JS
      expect(blocked["loaded"]).to eq false
      expect(blocked["ratio"]).to be_within(0.02).of(1.5)

      page.driver.browser.execute_cdp("Network.setBlockedURLs", urls: [])
      visit business_root_path
      expect_illustrations_loaded
      loaded_flow = page.evaluate_script("document.querySelector('.ba-lp-flow').getBoundingClientRect().height")
      expect(loaded_flow).to be_within(1).of(blocked["flow"])
    end
  end

  it "目次のリンクをキーボードで選ぶと該当セクションへ移動し、見出しが固定ヘッダーに隠れない。よくある質問は Enter で開閉できる" do
    visit_at(business_help_path, 375)

    link = find(".ba-help-toc a[href='#help-status']")
    page.execute_script("arguments[0].focus()", link)
    expect(page.evaluate_script("getComputedStyle(document.activeElement).boxShadow")).not_to eq "none"
    page.send_keys(:enter)
    expect(page).to have_current_path(/#help-status\z/, url: true)
    header_bottom = page.evaluate_script("document.querySelector('.ba-lp-header').getBoundingClientRect().bottom")
    title_top = page.evaluate_script("document.querySelector('#help-status-title').getBoundingClientRect().top")
    expect(title_top).to be >= header_bottom

    summary = find("#help-faq summary", text: "無料で使えますか？")
    page.execute_script("arguments[0].focus()", summary)
    page.send_keys(:enter)
    expect(page).to have_css("#help-faq details[open] p", text: "無料プランで使えます", visible: :visible)
    page.send_keys(:enter)
    expect(page).to have_no_css("#help-faq details[open]")
  end

  it "スマホのメニューから使い方を開け、PC の左ナビでは現在地になる" do
    sign_in_as(customer)
    set_viewport(375, 812)
    visit business_root_path
    find("#baMenuToggle").click
    within("#baMenuSheet") { click_link "使い方" }
    expect(page).to have_css("body.ba-body h1", text: "NAKAMAの使い方", wait: 10)
    expect(page).to have_css("button#baMenuToggle.is-current")
    expect(page).to have_no_css("#baMenuSheet", visible: :visible)

    set_viewport(1280)
    visit business_help_path
    expect(page).to have_css(".ba-sidenav a[aria-current='page']", text: "使い方")
  end

  it "タイムラインの「投稿する」から投稿でき、編集・削除の後はタイムラインへ戻る" do
    sign_in_as(customer)
    set_viewport(1280)
    visit business_timeline_path
    within(".ba-page-header") { click_link "投稿する" }
    expect(page).to have_css(".ba-visibility", text: "ログインしている全員が見られます")
    fill_in "タイトル", with: "初めての投稿"
    fill_in "本文", with: "よろしくお願いします。"
    click_button "投稿する"
    expect(page).to have_css("h1", text: "初めての投稿")
    expect(page).to have_text("投稿しました。NAKAMAにログインしている全員が見られます。")

    click_link "編集"
    fill_in "タイトル", with: "初めての投稿（更新）"
    click_button "更新する"
    expect(page).to have_css("h1", text: "初めての投稿（更新）")

    accept_confirm { click_link "削除" }
    expect(page).to have_current_path(business_timeline_path, wait: 10)
    expect(page).to have_no_css(".ba-post-card", text: "初めての投稿")
  end
end
