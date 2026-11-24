require "rails_helper"

# イベント詳細の楽曲欄(スマホ)。同じ楽曲表をCSSで1曲1行に組み替え、横スクロールせずに
# 複数曲の空きパートを見比べ、曲を開いて同じ参加チェック欄からエントリーできること。
#
# 他の system spec と同じ理由(このheadless Chrome環境では実クリックがDOMへ反映されないことがある)で、
# クリック・チェックは page.execute_script で行う。
RSpec.describe "イベント詳細の楽曲欄(スマホ1曲1行)", type: :system do
  before { driven_by :selenium_chrome_headless }
  after { reset_viewport_override }

  let(:community) { create(:community) }
  let(:owner) { create(:customer, name: "主催者") }
  let(:member) { create(:customer, name: "一般メンバー") }
  let(:guitarist) { create(:customer, name: "ギター担当") }
  let(:drummer) { create(:customer, name: "ドラム会員") }
  let(:event) do
    create(:event, :event_with_songs, community: community, customer: owner,
                                     event_start_time: 10.days.from_now, event_end_time: 10.days.from_now + 2.hours,
                                     event_entry_deadline: 5.days.from_now)
  end
  let!(:open_song) { create(:song, event: event, song_name: "とても長い曲名のテストソング〜ロングバージョン〜", position: 1) }
  let!(:open_vocal) { create(:join_part, song: open_song, join_part_name: "Vocal") }
  let!(:open_guitar) { create(:join_part, song: open_song, join_part_name: "Guitar") }
  let!(:open_guitar2) { create(:join_part, song: open_song, join_part_name: "Guitar2") }
  let!(:open_other) { create(:join_part, song: open_song, join_part_name: "Other") }
  let!(:complete_song) { create(:song, event: event, song_name: "成立した曲", position: 2) }
  let!(:complete_drums) { create(:join_part, song: complete_song, join_part_name: "Drums") }
  let!(:band_song) { create(:song, event: event, song_name: "バンドの曲", position: 3) }

  before do
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    [owner, member, guitarist, drummer].each { |c| CommunityCustomer.find_or_create_by!(customer: c, community: community) }
    create(:join_part_customer, join_part: open_guitar, customer: guitarist)
    create(:join_part_customer, join_part: complete_drums, customer: drummer)
    event.event_bands.create!(name: "固定バンド", selected_song_ids: [band_song.id]).tap do |band|
      band.members.create!(part_name: "Drums", customer: drummer)
    end
  end

  def sign_in_via_form(target)
    visit new_customer_session_path
    fill_in "customer_email", with: target.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def row(song) = "#event-song-details-#{song.id}"

  def toggle_row(song)
    page.execute_script("document.querySelector('#{row(song)} .song-row-toggle').click()")
  end

  def check_part(join_part)
    page.execute_script(<<~JS)
      (function () {
        var cb = document.getElementById('event_join_part_ids_#{join_part.id}');
        cb.checked = true;
        cb.dispatchEvent(new Event('change', { bubbles: true }));
      })()
    JS
  end

  # 楽曲欄(参加フォーム全体)の右端が画面内にあり、楽曲の箱も横スクロールしないこと。
  # ページ全体の scrollWidth は共通ヘッダー(.customer-menu-sp)の既存の横溢れを含むため使わない。
  def horizontal_overflow
    page.evaluate_script(<<~JS)
      (function () {
        var width = document.documentElement.clientWidth;
        var form = document.querySelector('.event-songs-join-form');
        var maxRight = form.getBoundingClientRect().right;
        form.querySelectorAll('*').forEach(function (el) {
          var rect = el.getBoundingClientRect();
          if (rect.width > 0 && rect.right > maxRight) maxRight = rect.right;
        });
        var box = document.querySelector('.responsive-box');
        return Math.max(maxRight - width, box.scrollWidth - box.clientWidth);
      })()
    JS
  end

  # 確認用。EVENT_SONGS_SCREENSHOT_DIR を指定したときだけ、対象位置までスクロールして撮る。
  def screenshot(name, scroll_to: ".event-songs-join-form")
    dir = ENV["EVENT_SONGS_SCREENSHOT_DIR"]
    return if dir.blank?

    page.execute_script("var el = document.querySelector(#{scroll_to.to_json}); if (el) el.scrollIntoView({ block: 'start' });")
    page.save_screenshot(File.join(dir, "#{name}.png"))
  end

  context "スマホ幅375px" do
    before do
      sign_in_via_form(member)
      use_mobile_viewport(width: 375, height: 812)
      visit public_event_path(event)
      expect(page).to have_selector(".song-part-summary", visible: true, wait: 10)
    end

    it "横にはみ出さず、複数曲のパート別状況を初期表示で一覧できる" do
      expect(horizontal_overflow).to be <= 1
      expect(page).to have_no_selector(".event-songs-table thead", visible: true)

      within(row(open_song)) do
        expect(page).to have_selector(".song-part-summary__item--open", text: /\AVo\s+募集中\z/)
        expect(page).to have_selector(".song-part-summary__item--partial", text: /\AGt\s+担当あり\s+空き1\z/)
        expect(page).to have_selector(".song-part-summary__item--none", text: /\ABa\s+対象外\z/)
        expect(page).to have_selector(".song-part-summary__item--open", text: /\AOther\s+募集中\z/)
        expect(page).to have_no_selector(".js-join-part-checkbox", visible: true)
      end
      within(row(complete_song)) do
        expect(page).to have_selector(".song-part-summary__item--filled", text: /\ADr\s+担当あり\z/)
        expect(page).to have_no_selector(".song-part-summary__item", text: "Other")
      end
      within(row(band_song)) do
        expect(page).to have_selector(".badge", text: "バンド出演🎸")
        expect(page).to have_selector(".song-band-members", text: "Drums: ドラム会員", visible: true)
        expect(page).to have_no_selector(".song-part-summary")
      end
      screenshot("01_mobile_list")
    end

    it "曲を開いてパートを選び、閉じても・フィルターを切り替えても選択が残り、参加確認へ進める" do
      toggle_row(open_song)
      within(row(open_song)) do
        expect(page).to have_selector(".song-row-toggle[aria-expanded='true']", text: "閉じる")
        expect(page).to have_selector(".js-join-part-checkbox", count: 4, visible: true)
        expect(page).to have_selector(".member-display", text: "ギター担当", visible: true)
        expect(page).to have_selector(".song-cheer-cell", visible: true)
      end
      check_part(open_vocal)
      expect(horizontal_overflow).to be <= 1
      screenshot("02_mobile_opened", scroll_to: row(open_song))

      toggle_row(open_song)
      expect(page).to have_selector("#{row(open_song)} .song-row-toggle__selected", text: "選択中", visible: true)
      expect(page).to have_button("参加確認画面へ", disabled: false)

      page.execute_script("document.getElementById('filter-complete').click()")
      expect(page).to have_no_selector(row(open_song), visible: true)
      expect(page).to have_selector(row(complete_song), visible: true)
      page.execute_script("document.getElementById('filter-vacant').click()")
      expect(page).to have_selector(row(open_song), visible: true)
      expect(page).to have_no_selector(row(band_song), visible: true)
      page.execute_script("document.getElementById('filter-all').click()")
      expect(page).to have_selector(row(band_song), visible: true)

      toggle_row(open_song)
      expect(find("#event_join_part_ids_#{open_vocal.id}")).to be_checked
      screenshot("03_mobile_reopened", scroll_to: row(open_song))

      accept_confirm("参加申請しますか？") { click_button "参加確認画面へ" }
      expect(page).to have_content("【#{open_song.song_name}】の曲に【Vocal】で参加！", wait: 10)
      screenshot("04_join_confirm", scroll_to: "body")
    end

    it "バンド出演曲は開いても一般エントリーのチェック欄を出さない" do
      toggle_row(band_song)
      within(row(band_song)) do
        expect(page).to have_content("バンド出演曲のため一般エントリーはありません")
        expect(page).to have_no_selector(".js-join-part-checkbox")
      end
    end
  end

  it "PC幅では従来の楽曲表(見出し・パート列)のままで、開閉ボタンを出さない" do
    sign_in_via_form(member)
    use_desktop_viewport(width: 1280, height: 900)
    visit public_event_path(event)

    expect(page).to have_selector(".event-songs-table thead th", text: "参加フォーム", visible: true, wait: 10)
    expect(page).to have_selector(".event-songs-table thead th", text: "Vocal", visible: true)
    expect(page).to have_selector("#event_join_part_ids_#{open_vocal.id}", visible: true)
    expect(page).to have_no_selector(".song-row-toggle", visible: true)
    expect(page).to have_no_selector(".song-part-summary", visible: true)
    screenshot("05_pc_table")
  end
end
