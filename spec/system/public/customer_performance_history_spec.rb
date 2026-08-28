require "rails_helper"

# プロフィール詳細画面の「演奏実績」欄(.performance-history-scroll)が、実績件数に応じて
# 欄内で縦スクロールし、ページ全体を極端に縦長にしない・新たな横スクロールを生まないことの
# 回帰防止テスト。
#
# spec/system/public/customer_song_part_mobile_overflow_spec.rbと同じ手法
# (selenium_chrome_headless + CDPのEmulation.setDeviceMetricsOverride)でPC幅・スマホ幅を再現する。
RSpec.describe "プロフィール詳細画面の演奏実績スクロール", type: :system, js: true do
  let(:customer) { create(:customer) }
  let(:community) { create(:community) }

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def set_viewport(width:, height: 900, mobile: false)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: height, deviceScaleFactor: mobile ? 2 : 1, mobile: mobile
    )
  end

  # 終了済みイベント(:event factoryのデフォルト日時は2023年)への出演実績を作る。
  def create_performances(count)
    count.times do |i|
      event = create(:event, :event_with_songs, community: community)
      song = create(:song, event: event, song_name: "実績曲#{i}", artist_name: "アーティスト#{i}")
      join_part = create(:join_part, song: song, join_part_name: "Vocal")
      create(:join_part_customer, join_part: join_part, customer: customer)
    end
  end

  def scroll_container_style
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector('.performance-history-scroll');
        if (!el) return null;
        var cs = getComputedStyle(el);
        return {
          maxHeight: cs.maxHeight,
          overflowY: cs.overflowY,
          scrollHeight: el.scrollHeight,
          clientHeight: el.clientHeight
        };
      })()
    JS
  end

  before do
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
  end

  it "PC幅では max-height: 480px / overflow-y: auto になり、大量実績で欄内スクロールが発生すること" do
    create_performances(12)

    sign_in_via_form(customer)
    set_viewport(width: 1200)
    visit public_customer_path(customer)

    expect(page).to have_selector(".performance-history-scroll")
    style = scroll_container_style
    expect(style["maxHeight"]).to eq "480px"
    expect(style["overflowY"]).to eq "auto"
    expect(style["scrollHeight"]).to be > style["clientHeight"]
  end

  it "スマホ幅では max-height: 360px になること" do
    create_performances(12)

    sign_in_via_form(customer)
    set_viewport(width: 375, mobile: true)
    visit public_customer_path(customer)

    expect(page).to have_selector(".performance-history-scroll")
    expect(scroll_container_style["maxHeight"]).to eq "360px"
  end

  it "実績が少ないときは内容の高さのままで欄内スクロールが発生しないこと" do
    create_performances(1)

    sign_in_via_form(customer)
    set_viewport(width: 1200)
    visit public_customer_path(customer)

    expect(page).to have_selector(".performance-history-scroll")
    style = scroll_container_style
    expect(style["scrollHeight"]).to be <= style["clientHeight"] + 1 # サブピクセル誤差許容
  end

  it "スクロール欄自身と子要素が画面幅内に収まり、新たな横スクロールを生まないこと" do
    create_performances(12)

    sign_in_via_form(customer)
    set_viewport(width: 375, mobile: true)
    visit public_customer_path(customer)

    expect(page).to have_selector(".performance-history-scroll")
    overflow = page.evaluate_script(<<~JS)
      (function () {
        var box = document.querySelector('.performance-history-scroll');
        if (!box) return null;
        var clientWidth = document.documentElement.clientWidth;
        var maxRight = box.getBoundingClientRect().right;
        box.querySelectorAll('*').forEach(function (el) {
          var right = el.getBoundingClientRect().right;
          if (right > maxRight) maxRight = right;
        });
        return maxRight - clientWidth;
      })()
    JS
    expect(overflow).to be <= 1
  end

  it "内側の演奏履歴(details)を開いても欄内で内容を閲覧できること" do
    create_performances(3)

    sign_in_via_form(customer)
    set_viewport(width: 1200)
    visit public_customer_path(customer)

    within(".performance-history-scroll") do
      first("details summary").click
      expect(page).to have_selector("details[open]")
    end
  end

  it "演奏可能曲(.song-performance-list)にはスクロールクラスを付けないこと" do
    playable_event = create(:event, :event_with_songs, community: community)
    playable_song = create(:song, event: playable_event, song_name: "自己申告曲", artist_name: "アーティスト")
    create(:customer_song_part, customer: customer, song: playable_song, song_master: playable_song.song_master, part_name: "Guitar")

    sign_in_via_form(customer)
    set_viewport(width: 1200)
    visit public_customer_path(customer)

    expect(page).to have_content("演奏可能曲")
    expect(page).not_to have_selector(".performance-history-scroll")
  end
end
