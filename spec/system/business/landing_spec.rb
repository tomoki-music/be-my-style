require "rails_helper"

# Business のログイン前の紹介ページ(/business、body.ba-lp)を実ブラウザで確認する。
RSpec.describe "Business のログイン前の紹介ページ", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:customer) { create(:customer, domain_name: "business", onboarding_done: true) }

  def set_viewport(width, height = 900)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: width < 600
    )
  end

  def visit_landing(width)
    visit business_root_path
    set_viewport(width)
    visit business_root_path
    expect(page).to have_css("body.ba-lp h1", text: "出会いを、いっしょに動く力へ。")
  end

  def horizontal_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  # 見出しの各文字の表示行を調べ、改行が読点「、」の直後(または行が収まる場合は無し)だけで起きていること。
  def heading_breaks(selector)
    page.evaluate_script(<<~JS)
      (function () {
        var node = document.querySelector(#{selector.to_json}).firstChild;
        var text = node.textContent;
        var range = document.createRange();
        var breaks = [];
        var lastTop = null;
        for (var i = 0; i < text.length; i++) {
          range.setStart(node, i);
          range.setEnd(node, i + 1);
          var top = Math.round(range.getBoundingClientRect().top);
          if (lastTop !== null && top > lastTop + 4) breaks.push(text.slice(0, i));
          lastTop = top;
        }
        return breaks;
      })()
    JS
  end

  def rect(selector)
    page.evaluate_script("(function(){var r=document.querySelector(#{selector.to_json}).getBoundingClientRect();return {left: r.left, right: r.right, top: r.top, bottom: r.bottom, width: r.width, height: r.height};})()")
  end

  [320, 375, 430, 768, 1280].each do |width|
    it "幅#{width}px: 横にはみ出さず、見出しは語の途中で折り返さず、最初の画面に登録・ログインの操作がある" do
      visit_landing(width)

      expect(horizontal_overflow).to be <= 0
      expect(heading_breaks(".ba-lp-hero__title")).to all(end_with("、"))
      %w[.ba-lp-start__title .ba-lp-section__title].each { |selector| expect(heading_breaks(selector)).to eq([]), selector }
      all(".ba-flow__title").each_with_index do |_, index|
        expect(heading_breaks(".ba-flow__step:nth-child(#{index + 1}) .ba-flow__title")).to eq []
      end

      font_size = page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.ba-lp-hero__title')).fontSize)")
      expect(font_size).to be_between(28, 34) if width < 600

      signup = rect(".ba-lp-hero .ba-lp-actions__primary")
      expect(signup["bottom"]).to be <= 900
      expect(signup["height"]).to be >= 44
      expect(page).to have_css("header.ba-lp-header a", text: "ログイン", visible: :visible)
      page.save_screenshot(Rails.root.join("tmp/screenshots/business_landing_#{width}.png").to_s)
    end
  end

  it "ヘッダーは幅 360px 以上でログインと「無料で始める」、それ未満はログインだけを出し、ロゴと重ならない" do
    visit_landing(320)
    expect(page).to have_no_css("header .ba-lp-header__signup", visible: :visible)

    visit_landing(375)
    expect(page).to have_css("header .ba-lp-header__signup", text: "無料で始める", visible: :visible)
    logo = rect(".ba-lp-header .ba-lp-brand")
    login = rect(".ba-lp-header__login")
    expect(logo["right"]).to be <= login["left"]
  end

  it "「無料で始める」は Business の新規登録、「ログイン」は Business のログインへ進み、ログイン後は同じ /business がホームになる" do
    visit_landing(375)
    find(".ba-lp-hero .ba-lp-actions__primary").click
    expect(page).to have_current_path(new_business_customer_registration_path, wait: 10)
    expect(page).to have_text("投稿・プロジェクト・コミュニティを始めましょう")

    visit business_root_path
    within(".ba-lp-hero") { click_link "ログイン" }
    expect(page).to have_current_path(new_business_customer_session_path, wait: 10)
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"

    expect(page).to have_current_path(business_root_path, wait: 10)
    expect(page).to have_css("body.ba-body .ba-home")
    expect(page).to have_no_css(".ba-lp-hero")
  end

  it "キーボードだけで本文へのスキップ・ロゴ・使い方・ログイン・無料で始めるの順に移動でき、フォーカスが見える" do
    visit_landing(1280)

    page.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.className")).to eq "ba-lp-skip"
    expect(rect(".ba-lp-skip")["top"]).to be >= 0

    page.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.getAttribute('aria-label')")).to eq "NAKAMA トップ"
    page.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.textContent.trim()")).to eq "使い方"
    page.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.textContent.trim()")).to eq "ログイン"
    page.send_keys(:tab)
    expect(page.evaluate_script("document.activeElement.textContent.trim()")).to eq "無料で始める"
    focus_ring = page.evaluate_script("getComputedStyle(document.activeElement).boxShadow + ' ' + getComputedStyle(document.activeElement).outlineStyle")
    expect(focus_ring).not_to eq "none none"

    visit_landing(1280)
    page.send_keys(:tab)
    page.send_keys(:enter)
    expect(page.evaluate_script("document.activeElement.id")).to eq "ba-lp-main"
  end

  it "音楽のトップと歌声の紹介ページには紹介ページのスタイル(body.ba-lp)が当たらない" do
    visit root_path
    expect(page).to have_no_css("body.ba-lp, body.ba-body")
    expect(horizontal_overflow).to be <= 0

    visit public_singing_lp_path
    expect(page).to have_no_css("body.ba-lp, body.ba-body")
  end
end
