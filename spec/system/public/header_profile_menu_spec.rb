require "rails_helper"

# PCヘッダー右端プロフィールの Bootstrap4 dropdown の回帰防止。
# application.js から bootstrap-sprockets を外し bootstrap 単体にした変更
# （data-api ハンドラの二重登録を解消）の保護も兼ねる。
RSpec.describe "PCヘッダー プロフィールドロップダウン", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer, name: "ヘッダー確認ユーザー") }

  def sign_in_via_form(target)
    visit new_customer_session_path
    fill_in "customer_email", with: target.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  before do
    sign_in_via_form(customer)
    visit public_customer_feedbacks_path
  end

  it "Bootstrap の dropdown click data-api が document に一度だけバインドされている" do
    count = page.evaluate_script(<<~JS)
      (function () {
        var ev = window.jQuery && window.jQuery._data(document, "events");
        if (!ev || !ev.click) return -1;
        return ev.click.filter(function (h) { return h.selector === '[data-toggle="dropdown"]'; }).length;
      })()
    JS
    expect(count).to eq(1)
  end

  it "トグルのクリックで開き、もう一度のクリックで閉じる（二重トグルで即閉じしない）" do
    # sticky ヘッダー内はヘッドレスのネイティブクリックが不安定なため実 DOM の click() を使う。
    # 二重バインドがあると 1 クリックで toggle が2回走り「開かない」ため、この開閉自体が非二重の証拠。
    toggle = "document.querySelector('.customer-profile-menu__toggle').click()"

    page.execute_script(toggle)
    expect(page).to have_css(".customer-profile-menu .dropdown-menu.show")

    within(".customer-profile-menu .dropdown-menu") do
      expect(page).to have_link("マイページ", href: public_customer_path(customer))
      expect(page).to have_link("BeMyStyleとは？", href: public_homes_about_path)
      expect(page).to have_link("ご意見BOX", href: new_public_customer_feedback_path)
      expect(page).to have_button("ログアウト")
    end

    page.execute_script(toggle)
    expect(page).to have_no_css(".customer-profile-menu .dropdown-menu.show")
  end

  it "メニュー外のクリックで閉じる" do
    page.execute_script("document.querySelector('.customer-profile-menu__toggle').click()")
    expect(page).to have_css(".customer-profile-menu .dropdown-menu.show")

    page.execute_script("document.body.click()")
    expect(page).to have_no_css(".customer-profile-menu .dropdown-menu.show")
  end
end
