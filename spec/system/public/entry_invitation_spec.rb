require "rails_helper"

# 演奏経験者へのエントリー依頼パネル(.entry-invitation-panel)。
# パネル全体が 1 つの GET フォームで、曲・パートをまたいで候補を選び、1 回の操作で
# 確認画面へ進む。モバイル横スクロール回帰防止も兼ねる。
#
# 注記: event_request_markdown_toolbar_spec.rb と同じ理由(このheadless Chrome環境では
# Seleniumの実クリック/checkがDOMへ反映されない既知の環境制約)により、
# チェック操作・送信は page.execute_script で直接行う。
# レイアウト検証は CDP Emulation.setDeviceMetricsOverride 方式。
RSpec.describe "エントリー依頼パネル（PC/スマホ）", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:community) { create(:community) }
  let(:owner) { create(:customer, :customer_with_parts, name: "オーナー") }
  let(:experienced_a) { create(:customer, name: "経験Ａ") }
  let(:experienced_b) { create(:customer, name: "経験Ｂ") }

  let(:past_event) do
    create(:event, :event_with_songs, community: community, customer: owner,
                   event_start_time: 3.days.ago, event_end_time: 2.days.ago, event_entry_deadline: 4.days.ago)
  end
  let(:current_event) do
    create(:event, :event_with_songs, community: community, customer: owner,
                   event_start_time: 2.days.from_now, event_end_time: 3.days.from_now, event_entry_deadline: 1.day.from_now)
  end
  let(:past_song) { create(:song, event: past_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:current_song) { create(:song, event: current_event, song_name: "共通曲", artist_name: "共通アーティスト") }
  let(:past_vocal) { create(:join_part, song: past_song, join_part_name: "Vocal") }
  let(:past_guitar) { create(:join_part, song: past_song, join_part_name: "Guitar") }
  let(:current_vocal) { create(:join_part, song: current_song, join_part_name: "Vocal") }
  let(:current_guitar) { create(:join_part, song: current_song, join_part_name: "Guitar") }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    [owner, experienced_a, experienced_b].each { |c| CommunityCustomer.find_or_create_by!(customer: c, community: community) }
    current_vocal
    current_guitar
    create(:join_part_customer, join_part: past_vocal, customer: experienced_a)
    create(:join_part_customer, join_part: past_guitar, customer: experienced_b)
  end

  def sign_in_via_form(target)
    visit new_customer_session_path
    fill_in "customer_email", with: target.email
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

  def checkbox_id(song, part, customer)
    "entry_invitation_target_#{song.id}_#{part.id}_#{customer.id}"
  end

  def check_via_js(id)
    page.execute_script("document.getElementById(#{id.to_json}).checked = true")
  end

  def submit_panel
    page.execute_script("document.querySelector('.entry-invitation-panel__form .js-entry-invitation-submit').click()")
  end

  def expect_panel_within_viewport
    overflow = page.evaluate_script(<<~JS)
      (function () {
        var panel = document.querySelector('.entry-invitation-panel');
        if (!panel) return null;
        var clientWidth = document.documentElement.clientWidth;
        var maxRight = panel.getBoundingClientRect().right;
        panel.querySelectorAll('*').forEach(function (el) {
          var right = el.getBoundingClientRect().right;
          if (right > maxRight) maxRight = right;
        });
        return maxRight - clientWidth;
      })()
    JS
    expect(overflow).to be <= 1
  end

  [320, 375, 414].each do |width|
    it "#{width}px幅でエントリー依頼パネルが画面外にはみ出さない" do
      sign_in_via_form(owner)
      set_mobile_viewport(width)
      visit public_event_path(current_event)

      expect(page).to have_selector(".entry-invitation-panel")
      expect_panel_within_viewport
    end
  end

  it "ページ内の送信ボタンは 1 つだけ" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector(".js-entry-invitation-submit", count: 1)
  end

  it "複数の曲・パートから選んだ人だけが 1 回の操作で確認画面に出る" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector(".entry-invitation-panel")

    check_via_js(checkbox_id(current_song, current_vocal, experienced_a))
    check_via_js(checkbox_id(current_song, current_guitar, experienced_b))
    submit_panel

    expect(page).to have_content("エントリー依頼の送信確認")
    expect(page).to have_content("経験Ａ")
    expect(page).to have_content("経験Ｂ")
    expect(page).to have_content("Vocal")
    expect(page).to have_content("Guitar")
    expect(page).to have_content("2人")
  end

  it "未選択で送信すると警告が出て遷移しない" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector(".entry-invitation-panel")

    message = accept_alert { submit_panel }

    expect(message).to include "選択"
    expect(page).to have_selector(".entry-invitation-panel")
  end
end
