require "rails_helper"

# PC ヘッダーの通知ベルを、上部バーの孤立した位置から
# .customer-menu-pc 内の右端ユーティリティ領域(.customer-menu-pc__account:
# 通知ベル + プロフィール dropdown)へ移した変更の回帰防止テスト。
#
# 実ブラウザ(selenium_chrome_headless + CDP)で代表的な PC 幅を再現し、
#   - 主要 6 項目が 1 行に収まる
#   - 通知ベルとプロフィールが右側の一群に見える(横並び・近接)
#   - 各要素が重ならない / 横スクロールが出ない
#   - dropdown が viewport 内に収まる
# を検証する。dropdown 開閉は sticky ヘッダー内クリックが headless で不安定なため
# header_profile_menu_spec.rb と同じくプラグイン単体呼び出しで開く。
RSpec.describe "PCヘッダー: 通知ベル + プロフィールの右端ユーティリティ領域", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer, name: "ヘッダーベル確認ユーザー") }

  def sign_in_via_form(target)
    visit new_customer_session_path
    fill_in "customer_email", with: target.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def set_desktop_viewport(width, height = 900)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 1, mobile: false
    )
  end

  before do
    sign_in_via_form(customer)
    visit public_customer_feedbacks_path
  end

  [1024, 1280, 1440].each do |width|
    context "#{width}px 幅" do
      before do
        set_desktop_viewport(width)
        visit public_customer_feedbacks_path
        expect(page).to have_css(".customer-menu-pc__account", visible: :all)
      end

      it "主要 6 項目が 1 行に収まる" do
        rows = page.evaluate_script(<<~JS)
          Array.from(document.querySelectorAll('.customer-menu-pc__main > li'))
            .map(function (li) { return Math.round(li.getBoundingClientRect().top); })
        JS
        expect(rows.size).to eq(6)
        expect(rows.uniq.size).to eq(1)
      end

      it "通知ベルはプロフィールの左側にあり、両者が近接した一群に見える" do
        geo = page.evaluate_script(<<~JS)
          (function () {
            var account = document.querySelector('.customer-menu-pc__account');
            var bell = document.querySelector('.customer-menu-pc__notification');
            var profile = document.querySelector('.customer-menu-pc__account .customer-profile-menu');
            var main = document.querySelector('.customer-menu-pc__main');
            var b = bell.getBoundingClientRect();
            var p = profile.getBoundingClientRect();
            var a = account.getBoundingClientRect();
            var m = main.getBoundingClientRect();
            return {
              bellRight: b.right, profileLeft: p.left,
              gap: p.left - b.right,
              bellCenterY: b.top + b.height / 2,
              profileCenterY: p.top + p.height / 2,
              bellInsideAccount: b.left >= a.left - 1 && b.right <= a.right + 1,
              profileInsideAccount: p.left >= a.left - 1 && p.right <= a.right + 1,
              accountLeftMinusMainRight: a.left - m.right
            };
          })()
        JS

        # ベルがプロフィールより左
        expect(geo["bellRight"]).to be <= geo["profileLeft"] + 1
        # 間隔は詰まりすぎず開きすぎず(8〜12px 目安、サブピクセル誤差込みで許容幅を持たせる)
        expect(geo["gap"]).to be_between(4, 20)
        # 縦位置がそろっている
        expect((geo["bellCenterY"] - geo["profileCenterY"]).abs).to be <= 4
        # どちらも同じユーティリティ領域の内側
        expect(geo["bellInsideAccount"]).to be true
        expect(geo["profileInsideAccount"]).to be true
        # メニュー本体とユーティリティ領域の間に不自然な空白がない
        expect(geo["accountLeftMinusMainRight"]).to be_between(-1, 60)
      end

      it "各要素が重ならず、横スクロールが発生しない" do
        overflow = page.evaluate_script(
          "document.documentElement.scrollWidth - document.documentElement.clientWidth"
        )
        expect(overflow).to be <= 1

        overlap = page.evaluate_script(<<~JS)
          (function () {
            var bell = document.querySelector('.customer-menu-pc__notification').getBoundingClientRect();
            var toggle = document.querySelector('.customer-profile-menu__toggle').getBoundingClientRect();
            return bell.right > toggle.left + 1;
          })()
        JS
        expect(overlap).to be false
      end

      it "プロフィール dropdown が viewport 内に収まる" do
        page.evaluate_script("window.jQuery('.customer-profile-menu__toggle').dropdown('toggle')")
        # Popper による位置決めは次フレームで確定するため少し待つ
        expect(page).to have_css(".customer-profile-menu .dropdown-menu.show", visible: :all)
        sleep 0.4

        within_viewport = page.evaluate_script(<<~JS)
          (function () {
            var menu = document.querySelector('.customer-profile-menu .dropdown-menu.show');
            if (!menu) return null;
            var r = menu.getBoundingClientRect();
            return r.left >= -1 && r.right <= window.innerWidth + 1 && r.top >= -1;
          })()
        JS
        expect(within_viewport).to be true
      end
    end
  end

  it "上部バー(.header-sign-in-list)は PC では通知ベルを二重表示しない" do
    set_desktop_viewport(1280)
    visit public_customer_feedbacks_path

    visible_bells = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("a[href$='/notifications'] i.fa-bell"))
        .filter(function (i) {
          var el = i;
          while (el) {
            if (getComputedStyle(el).display === 'none') return false;
            el = el.parentElement;
          }
          return true;
        }).length
    JS
    expect(visible_bells).to eq(1)
  end
end
