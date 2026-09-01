require "rails_helper"

# application.js から bootstrap-sprockets を外し bootstrap 単体にした変更
# （Bootstrap の各プラグインと data-api ハンドラが二重登録されるのを解消）の回帰防止。
#
# 二重登録は dropdown だけが実害を受ける（他コンポーネントは遷移ガードで一見動く）ため、
# 「ハンドラが 1 回だけ登録されている」ことを実ブラウザで確認する。
# 開閉の対話そのものは spec/views/layouts/_header_menu.html.haml_spec.rb（構造）と
# 手動確認でカバーする（sticky ヘッダー内のクリックは headless で不安定なため CI ゲートにしない）。
RSpec.describe "PCヘッダー: Bootstrap JS の単一ロード", type: :system do
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

  it "全 Bootstrap プラグインが読み込まれ、data-api ハンドラが二重登録されていない" do
    info = page.evaluate_script(<<~JS)
      (function () {
        var $ = window.jQuery;
        var ev = ($ && $._data(document, "events")) || {};
        function countClick(sel) {
          return (ev.click || []).filter(function (h) { return h.selector === sel; }).length;
        }
        var fn = {};
        ["dropdown", "modal", "collapse", "tab", "tooltip", "popover", "alert", "button", "carousel", "toast", "scrollspy"]
          .forEach(function (n) { fn[n] = typeof ($.fn[n]); });
        return {
          jquery: $ && $.fn.jquery,
          popper: typeof window.Popper,
          bootstrap: typeof window.bootstrap,
          fn: fn,
          dropdownClick: countClick('[data-toggle="dropdown"]'),
          dropdownFormClick: countClick('.dropdown form'),
          modalToggleClick: countClick('[data-toggle="modal"]'),
          carouselSlideClick: countClick('[data-slide], [data-slide-to]')
        };
      })()
    JS

    aggregate_failures do
      expect(info["popper"]).to eq("function")
      expect(info["bootstrap"]).to eq("object")
      info["fn"].each { |name, t| expect(t).to eq("function"), "$.fn.#{name} が未定義" }
      # 二重ロード時はいずれも 2 になる
      expect(info["dropdownClick"]).to eq(1)
      expect(info["dropdownFormClick"]).to eq(1)
      expect(info["modalToggleClick"]).to eq(1)
      expect(info["carouselSlideClick"]).to eq(1)
    end
  end

  it "プロフィールドロップダウンの markup と Bootstrap の関連付けが1組だけ存在する" do
    expect(page).to have_css('.customer-profile-menu .dropdown-toggle[data-toggle="dropdown"]', visible: :all, count: 1)
    expect(page).to have_css(".customer-profile-menu .dropdown-menu", visible: :all, count: 1)

    # プラグイン単体呼び出し（data-api を介さない）で開けること＝プラグインが壊れていない
    opened = page.evaluate_script(<<~JS)
      (function () {
        window.jQuery(".customer-profile-menu__toggle").dropdown("toggle");
        return document.querySelectorAll(".customer-profile-menu .dropdown-menu.show").length;
      })()
    JS
    expect(opened).to eq(1)
  end
end
