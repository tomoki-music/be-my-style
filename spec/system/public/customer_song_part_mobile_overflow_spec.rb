require "rails_helper"

# プロフィール編集画面の「演奏可能曲」欄(song-part-form)に、自由入力(曲名・アーティスト名)の
# テキストフィールドを追加した際の回帰防止テスト。
#
# spec/system/public/event_form_mobile_overflow_spec.rbと同じ手法
# (selenium_chrome_headless + CDPのEmulation.setDeviceMetricsOverride)で、
# 実際のモバイル幅を再現して検証する。
#
# 注記: このアプリのプロフィール編集画面には、本仕様と無関係な既存のグローバル要素
# (ヘッダーのスマホ用メニュー.customer-menu-sp、通知パネル.notifications等)が
# ページごとに異なる幅でdocument.scrollWidthへ影響するため(イベント一覧ページを
# 基準にした差分比較が使えない)、ページ全体のscrollWidthではなく.song-part-form自身と
# その子要素(自由入力欄を含む)が画面幅内に収まっているかを直接検証する
# (event_form_mobile_overflow_spec.rbのexpect_event_table_within_viewportと同じ考え方)。
RSpec.describe "プロフィール編集画面(演奏可能曲欄)のモバイル横スクロール", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:community) { create(:community) }
  let(:event) { create(:event, :event_with_songs, community: community) }
  let!(:song) { create(:song, event: event, song_name: "モバイル表示確認用の曲", artist_name: "アーティスト") }

  before do
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def set_mobile_viewport(width, height = 812)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: 2, mobile: true
    )
  end

  def expect_song_part_form_within_viewport
    overflow = page.evaluate_script(<<~JS)
      (function () {
        var form = document.querySelector('.song-part-form');
        if (!form) return null;
        var clientWidth = document.documentElement.clientWidth;
        var maxRight = form.getBoundingClientRect().right;
        form.querySelectorAll('input, select, button, label').forEach(function (el) {
          var right = el.getBoundingClientRect().right;
          if (right > maxRight) maxRight = right;
        });
        return maxRight - clientWidth;
      })()
    JS
    expect(overflow).to be <= 1 # サブピクセル誤差許容
  end

  [320, 375, 414].each do |width|
    it "#{width}px幅で演奏可能曲欄(自由入力欄を含む)が画面外にはみ出さないこと" do
      sign_in_via_form(customer)
      set_mobile_viewport(width)
      visit edit_public_customer_path(customer)

      expect(page).to have_selector(".song-part-form")
      expect_song_part_form_within_viewport
    end
  end

  it "375px幅で登録済みの演奏可能曲一覧が表示されていても画面外にはみ出さないこと" do
    create(:customer_song_part, customer: customer, song: song, song_master: song.song_master, part_name: "Vocal")

    sign_in_via_form(customer)
    set_mobile_viewport(375)
    visit edit_public_customer_path(customer)

    expect(page).to have_content("モバイル表示確認用の曲")
    expect_song_part_form_within_viewport
  end
end
