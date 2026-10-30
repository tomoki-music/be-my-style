require "rails_helper"

# NAKAMA の青いロゴが、画面幅ごとに決めた大きさ・縦横比で読み込まれ、操作部品がブランドブルーになること(実ブラウザ)。
RSpec.describe "Business のロゴと配色(実ブラウザ)", type: :system, js: true do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:customer) { create(:customer, domain_name: "business", onboarding_done: true) }
  # SVG の viewBox(横長ロゴ 935x206、シンボル 473x448)の縦横比。
  let(:logo_ratio) { 935.0 / 206 }
  let(:symbol_ratio) { 473.0 / 448 }

  def sign_in_as(customer)
    visit new_business_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_css(".ba-main", wait: 10)
  end

  def metrics!(width)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: width, height: 900, deviceScaleFactor: 1, mobile: width < 768)
  end

  # 表示中の画像の大きさと、読み込みが終わっているか(naturalWidth)を返す。非表示なら nil。
  def logo_box(selector)
    page.evaluate_script(<<~JS)
      (function(){
        var img = document.querySelector(#{selector.to_json});
        if (!img || getComputedStyle(img).display === "none") return null;
        var r = img.getBoundingClientRect();
        return { width: r.width, height: r.height, loaded: img.complete && img.naturalWidth > 0 };
      })()
    JS
  end

  def expect_logo(selector, height:, ratio:)
    box = nil
    Timeout.timeout(5) do
      sleep 0.1 until (box = logo_box(selector)) && box["loaded"]
    end
    expect(box["height"]).to be_within(0.5).of(height)
    expect(box["width"].to_f / box["height"]).to be_within(0.05).of(ratio)
  end

  def computed(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json}))[#{property.to_json}]")
  end

  it "ログイン前のトップ: 幅 400px 未満は 24px、それ以上は 28px の横長ロゴ。主ボタンはブランドブルー" do
    metrics!(320)
    visit business_root_path
    expect_logo(".ba-lp-header .ba-lp-brand__logo", height: 24, ratio: logo_ratio)

    metrics!(1280)
    visit business_root_path
    expect_logo(".ba-lp-header .ba-lp-brand__logo", height: 28, ratio: logo_ratio)
    expect(computed(".ba-lp-hero .ba-btn--primary", "backgroundColor")).to eq "rgb(40, 100, 217)"
  end

  it "Business の利用開始: ボタンは青の背景に白文字(Bootstrap の .btn の文字色に負けない)" do
    music_customer = create(:customer, onboarding_done: true)
    visit new_customer_session_path
    fill_in "customer_email", with: music_customer.email
    fill_in "customer_password", with: "password"
    find("input[type=submit]", match: :first).click
    expect(page).to have_no_current_path(new_customer_session_path, wait: 10)

    visit business_join_path
    expect(page).to have_current_path(business_join_path)
    expect(computed(".domain-auth__submit", "backgroundColor")).to eq "rgb(40, 100, 217)"
    expect(computed(".domain-auth__submit", "color")).to eq "rgb(255, 255, 255)"
  end

  it "ログイン後: スマホは上部バーに横長ロゴ、縮めた左ナビはシンボル、広い左ナビは横長ロゴ" do
    sign_in_as(customer)

    metrics!(375)
    visit business_root_path
    expect_logo(".ba-topbar .ba-brand__logo", height: 28, ratio: logo_ratio)
    expect(computed(".ba-bottomnav__link.is-current", "color")).to eq "rgb(40, 100, 217)"

    metrics!(1024)
    visit business_root_path
    expect(logo_box(".ba-sidenav .ba-brand__logo")).to be_nil
    expect_logo(".ba-sidenav .ba-brand__symbol", height: 36, ratio: symbol_ratio)

    metrics!(1280)
    visit business_root_path
    expect(logo_box(".ba-sidenav .ba-brand__symbol")).to be_nil
    expect_logo(".ba-sidenav .ba-brand__logo", height: 32, ratio: logo_ratio)
    expect(computed(".ba-sidenav__link.is-current", "color")).to eq "rgb(29, 79, 179)"
  end
end
