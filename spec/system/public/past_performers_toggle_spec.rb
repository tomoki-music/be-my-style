require "rails_helper"

# イベント詳細の楽曲表で、権限者向け「過去に演奏した人」欄(依頼候補・依頼フォーム)を
# 全曲共通の切り替えボタン1つで開閉する。初期状態は常にOFF。
#
# entry_invitation_spec.rb と同じ理由(このheadless Chrome環境ではSeleniumの実クリック/checkが
# DOMへ反映されないことがある)で、クリック・チェック・送信は page.execute_script で行う。
# キーボード操作は native button の Enter / Space を send_keys で確認する。
RSpec.describe "過去に演奏した人の表示切り替え", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:community) { create(:community) }
  let(:owner) { create(:customer, :customer_with_parts, name: "オーナー") }
  let(:experienced_a) { create(:customer, name: "経験Ａ") }

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
  let!(:current_vocal) { create(:join_part, song: current_song, join_part_name: "Vocal") }

  let(:toggle) { ".js-past-performers-toggle" }
  let(:candidate_checkbox_id) { "entry_invitation_target_#{current_song.id}_#{current_vocal.id}_#{experienced_a.id}" }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    [owner, experienced_a].each { |c| CommunityCustomer.find_or_create_by!(customer: c, community: community) }
    create(:join_part_customer, join_part: past_vocal, customer: experienced_a)
  end

  def sign_in_via_form(target)
    visit new_customer_session_path
    fill_in "customer_email", with: target.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def click_toggle_via_js
    page.execute_script("document.querySelector('.js-past-performers-toggle').click()")
  end

  def check_candidate_via_js
    page.execute_script(<<~JS)
      (function () {
        var cb = document.getElementById(#{candidate_checkbox_id.to_json});
        cb.checked = true;
        cb.dispatchEvent(new Event('change', { bubbles: true }));
      })()
    JS
  end

  def expect_collapsed
    expect(page).to have_selector(toggle, text: "過去に演奏した人を表示する")
    expect(find(toggle)["aria-expanded"]).to eq "false"
    expect(page).to have_no_selector(".entry-invitation-candidates-wrap", visible: true)
    expect(page).to have_no_selector(".entry-invitation-form__title", visible: true)
    expect(page).to have_no_selector(".js-entry-invitation-submit", visible: true)
    expect(page).to have_no_selector(".experienced-customers", visible: true)
  end

  def expect_expanded
    expect(page).to have_selector(toggle, text: "過去に演奏した人を非表示にする")
    expect(find(toggle)["aria-expanded"]).to eq "true"
    expect(page).to have_selector(".entry-invitation-candidates-wrap", visible: true)
    expect(page).to have_selector(".entry-invitation-form__title", text: "演奏経験者へエントリーをお願いする", visible: true)
    expect(page).to have_selector(".js-entry-invitation-submit", visible: true)
  end

  describe "権限者(オーナー)・PC幅" do
    before do
      sign_in_via_form(owner)
      page.driver.browser.manage.window.resize_to(1280, 900)
      visit public_event_path(current_event)
    end

    it "初期OFF→ONで表示→再度押すとOFF。参加フォーム・募集状況・フィルターは常に見える" do
      expect_collapsed
      expect(page).to have_selector("#submit_join_form", visible: true)
      expect(page).to have_selector("#event_join_part_ids_#{current_vocal.id}", visible: true)
      expect(page).to have_selector(".event-songs-table .text-danger", text: "募集中", visible: true)
      expect(page).to have_selector("#filter-all", visible: true)

      click_toggle_via_js
      expect_expanded

      click_toggle_via_js
      expect_collapsed
    end

    it "切り替えボタンを押してもフォームは送信されず、ページ遷移しない" do
      path_before = page.current_path
      click_toggle_via_js
      expect_expanded
      expect(page.current_path).to eq path_before
      expect(page).to have_no_content("参加確認")
    end

    it "ページを開き直すとOFFに戻る" do
      click_toggle_via_js
      expect_expanded

      visit public_event_path(current_event)
      expect_collapsed
    end

    it "キーボード(Enter / Space)で開閉できる" do
      find(toggle).send_keys(:enter)
      expect_expanded
      find(toggle).send_keys(:space)
      expect_collapsed
    end

    it "楽曲フィルターと併用できる(フィルター後も開閉でき、開閉後もフィルターが効く)" do
      page.execute_script("document.getElementById('filter-complete').click()")
      expect(page).to have_no_selector(".event-songs-table tbody tr.vacant", visible: true)

      click_toggle_via_js
      expect(find(toggle)["aria-expanded"]).to eq "true"
      expect(page).to have_no_selector(".event-songs-table tbody tr.vacant", visible: true)

      page.execute_script("document.getElementById('filter-vacant').click()")
      expect(page).to have_selector(".event-songs-table tbody tr.vacant .entry-invitation-candidates-wrap", visible: true)

      click_toggle_via_js
      expect_collapsed
      expect(page).to have_selector(".event-songs-table tbody tr.vacant", visible: true)
    end

    it "ONの状態で候補を選ぶと、既存どおり依頼の確認画面へ進み送信できる" do
      click_toggle_via_js
      check_candidate_via_js
      expect(page).to have_selector(".js-entry-invitation-submit:not([disabled])")
      page.execute_script("document.querySelector('#entry-invitation-form .js-entry-invitation-submit').click()")

      expect(page).to have_content("エントリー依頼の送信確認")
      expect(page).to have_content("経験Ａ")

      expect {
        page.execute_script("document.querySelector('input[type=submit][value=\"この内容で送信する\"]').click()")
        expect(page).to have_current_path(public_event_path(current_event), wait: 10)
      }.to change(EntryInvitation, :count).by(1)
    end

    it "OFFの状態で通常の参加操作をしても依頼(targets[])は送られない" do
      # 開いて候補を選んだあとに閉じても、参加フォームの送信に targets[] は混ざらない
      click_toggle_via_js
      check_candidate_via_js
      click_toggle_via_js
      expect_collapsed

      page.execute_script(<<~JS)
        (function () {
          var cb = document.getElementById('event_join_part_ids_#{current_vocal.id}');
          cb.checked = true;
          cb.dispatchEvent(new Event('change', { bubbles: true }));
          window.confirm = function () { return true; };
          document.getElementById('join_btn').submit();
        })()
      JS

      expect(page).to have_current_path(/join_confirm/, wait: 10)
      expect(page.current_url).not_to include("targets")
      expect(EntryInvitation.count).to eq 0
    end
  end

  describe "正式なマネージャー(is_owner: manager)" do
    let(:assigned_manager) do
      create(:customer, :customer_with_parts, name: "担当マネージャー", is_owner: :manager).tap do |m|
        CommunityEventEditor.create!(customer: m, community: community)
        CommunityCustomer.find_or_create_by!(customer: m, community: community)
      end
    end
    let(:unassigned_manager) do
      create(:customer, :customer_with_parts, name: "担当外マネージャー", is_owner: :manager).tap do |m|
        CommunityEventEditor.create!(customer: m, community: create(:community))
        CommunityCustomer.find_or_create_by!(customer: m, community: community)
      end
    end

    it "担当コミュニティのイベントでは初期OFFから開き、依頼を確認・送信できる" do
      sign_in_via_form(assigned_manager)
      page.driver.browser.manage.window.resize_to(1280, 900)
      visit public_event_path(current_event)

      expect_collapsed
      click_toggle_via_js
      expect_expanded
      check_candidate_via_js
      expect(page).to have_selector(".js-entry-invitation-submit:not([disabled])")
      page.execute_script("document.querySelector('#entry-invitation-form .js-entry-invitation-submit').click()")

      expect(page).to have_content("エントリー依頼の送信確認")
      expect(page).to have_content("経験Ａ")

      expect {
        page.execute_script("document.querySelector('input[type=submit][value=\"この内容で送信する\"]').click()")
        expect(page).to have_current_path(public_event_path(current_event), wait: 10)
      }.to change { EntryInvitation.where(requested_by_customer: assigned_manager).count }.by(1)
    end

    it "担当外のマネージャーには切り替えボタンも依頼フォームも出ず、経験者氏名は表示される" do
      sign_in_via_form(unassigned_manager)
      page.driver.browser.manage.window.resize_to(1280, 900)
      visit public_event_path(current_event)

      expect(page).to have_selector("#submit_join_form")
      expect(page).to have_no_selector(toggle)
      expect(page).to have_no_selector("#entry-invitation-form")
      expect(page).to have_selector(".experienced-customers", text: "経験Ａ", visible: true)
    end
  end

  describe "権限者(オーナー)・スマホ幅(375px)" do
    before do
      sign_in_via_form(owner)
      page.driver.browser.execute_cdp(
        "Emulation.setDeviceMetricsOverride",
        width: 375, height: 812, deviceScaleFactor: 2, mobile: true
      )
      visit public_event_path(current_event)
    end

    after do
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end

    it "スマホでも初期OFF、ONにすると開いた曲のパート欄に経験者を表示。ボタンは画面幅からはみ出さない" do
      expect_collapsed
      expect(page).to have_selector(".song-part-summary", visible: true)

      overflow = page.evaluate_script(<<~JS)
        (function () {
          var rect = document.querySelector('.js-past-performers-toggle').getBoundingClientRect();
          return rect.right - document.documentElement.clientWidth;
        })()
      JS
      expect(overflow).to be <= 1

      click_toggle_via_js
      # スマホでは曲の詳細を開くと、パート欄の経験者(依頼候補)が見える。
      expect(page).to have_no_selector(".entry-invitation-candidates-wrap", text: "経験Ａ", visible: true)
      page.execute_script("document.querySelector('#event-song-details-#{current_song.id} .song-row-toggle').click()")
      expect(page).to have_selector("#event-song-details-#{current_song.id} .entry-invitation-candidates-wrap", text: "経験Ａ", visible: true)
      expect(page).to have_selector(".entry-invitation-form__mobile-hint", visible: true)
    end
  end
end
