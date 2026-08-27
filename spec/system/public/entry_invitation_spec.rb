require "rails_helper"

# 演奏経験者へのエントリー依頼パネル(.entry-invitation-panel)の
# モバイル横スクロール回帰防止 + 選択→確認画面フロー。
#
# 注記: event_request_markdown_toolbar_spec.rb と同じ理由(このheadless Chrome環境では
# Seleniumの実クリック/checkがDOMへ反映されない既知の環境制約)により、
# チェック操作・ボタン押下は page.execute_script で直接行う。
# レイアウト検証は spec/system/public/customer_song_part_mobile_overflow_spec.rb と同じ
# CDP Emulation.setDeviceMetricsOverride 方式。
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

  def check_via_js(id)
    page.execute_script("document.getElementById(#{id.to_json}).checked = true")
  end

  def click_submit_for(part_id)
    page.execute_script(
      "document.querySelector(\".entry-invitation[data-part-id='#{part_id}'] .js-entry-invitation-submit\").click()"
    )
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

  it "別の曲・パートの選択状態が混在せず、選んだ人だけが確認画面に出る" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector(".entry-invitation-panel")

    check_via_js("entry_invitation_customer_#{current_song.id}_#{current_vocal.id}_#{experienced_a.id}")
    click_submit_for(current_vocal.id)

    expect(page).to have_content("エントリー依頼の送信確認")
    expect(page).to have_content("経験Ａ")
    expect(page).not_to have_content("経験Ｂ")
    expect(page).to have_content("1人")
  end

  it "未選択で送信ボタンを押すと警告が出て遷移しない" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector(".entry-invitation-panel")

    message = accept_alert { click_submit_for(current_vocal.id) }

    expect(message).to include "選択"
    expect(page).to have_selector(".entry-invitation-panel")
  end
end
