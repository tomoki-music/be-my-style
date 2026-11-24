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
  let!(:second_song) { create(:song, event: event, song_name: "二曲目", position: 4) }
  let!(:second_bass) { create(:join_part, song: second_song, join_part_name: "Bass") }
  let(:outsider) { create(:customer, name: "コミュニティ外") }
  let(:band) { event.event_bands.find_by!(name: "固定バンド") }

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

  def chip(song, join_part) = "#{row(song)} .song-part-summary__entry[data-join-part-id='#{join_part.id}']"

  def tap_chip(song, join_part)
    page.execute_script("document.querySelector(#{chip(song, join_part).to_json}).click()")
  end

  def selected_part_ids
    page.evaluate_script("Array.from(document.querySelectorAll('input.js-join-part-checkbox:checked')).map(function (cb) { return Number(cb.value); })")
  end

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

  # 楽曲欄(バンド出演枠・絞り込み・参加フォームを含む行)が、地図の行の直後にあること。
  def songs_section_follows_map?
    page.evaluate_script(<<~JS)
      (function () {
        var section = document.querySelector('.event-songs-section-row');
        var prev = section && section.previousElementSibling;
        return !!(prev && prev.querySelector('#map') && section.querySelector('#event-bands') &&
                  section.querySelector('#filter-vacant') && section.querySelector('#join_btn') &&
                  document.querySelectorAll('#join_btn').length === 1);
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
        expect(page).to have_selector(".song-part-summary__item--filled", text: /\ADr\s+1人参加\s+追加可\z/)
        expect(page).to have_no_selector(".song-part-summary__item", text: "Other")
      end
      within(row(band_song)) do
        expect(page).to have_selector(".badge", text: "バンド出演🎸")
        expect(page).to have_selector(".song-band-members", text: "Drums: ドラム会員", visible: true)
        expect(page).to have_no_selector(".song-part-summary")
      end
      screenshot("01_mobile_list")
    end

    it "詳細を開いても参加チェック欄と「参加確認画面へ」は出さず、担当者・応援は見られる" do
      expect(page).to have_no_selector("#submit_join_form", visible: true)
      toggle_row(open_song)
      within(row(open_song)) do
        expect(page).to have_selector(".song-row-toggle[aria-expanded='true']", text: "閉じる")
        expect(page).to have_no_selector(".js-join-part-checkbox", visible: true)
        expect(page).to have_selector(".member-display", text: "ギター担当", visible: true)
        expect(page).to have_selector(".song-cheer-cell", visible: true)
      end
      expect(horizontal_overflow).to be <= 1
      screenshot("02_mobile_opened", scroll_to: row(open_song))
    end

    it "チップで同じ曲の複数パート・複数曲を選び、もう一度押すと解除でき、開閉やフィルター後も選択が残る" do
      tap_chip(open_song, open_vocal)
      tap_chip(open_song, open_guitar2)
      tap_chip(second_song, second_bass)
      tap_chip(complete_song, complete_drums)
      expect(selected_part_ids).to contain_exactly(open_vocal.id, open_guitar2.id, second_bass.id, complete_drums.id)
      expect(page).to have_selector("#{chip(open_song, open_vocal)}[aria-pressed='true']")
      expect(page).to have_selector("#{row(open_song)} .song-part-summary__item.is-selected .song-part-summary__check", text: "✓", count: 2, visible: true)
      expect(page).to have_selector(".event-join-fab__count", text: "4", visible: true)
      screenshot("03_mobile_chips_selected", scroll_to: row(open_song))

      tap_chip(complete_song, complete_drums)
      expect(page).to have_selector("#{chip(complete_song, complete_drums)}[aria-pressed='false']")
      expect(page).to have_no_selector("#{row(complete_song)} .song-part-summary__item.is-selected")
      expect(page).to have_selector(".event-join-fab__count", text: "3", visible: true)

      toggle_row(open_song)
      toggle_row(open_song)
      page.execute_script("document.getElementById('filter-complete').click()")
      expect(page).to have_no_selector(row(open_song), visible: true)
      page.execute_script("document.getElementById('filter-vacant').click()")
      page.execute_script("document.getElementById('filter-all').click()")
      expect(page).to have_selector(row(open_song), visible: true)
      expect(selected_part_ids).to contain_exactly(open_vocal.id, open_guitar2.id, second_bass.id)
      expect(page).to have_selector("#{row(open_song)} .song-part-summary__item.is-selected", count: 2)
      expect(page).to have_selector("#{row(open_song)} .song-row-toggle__selected", text: "選択中", visible: true)
    end

    it "対象外・バンド出演曲には操作ボタンを出さず、空きのある枠と担当者のいる枠は押せる" do
      within(row(open_song)) do
        expect(page).to have_selector(".song-part-summary__item--open .song-part-summary__entry", count: 2)
        expect(page).to have_selector(".song-part-summary__item--partial .song-part-summary__entry[data-join-part-id='#{open_guitar2.id}']")
        expect(page).to have_no_selector(".song-part-summary__item--none .song-part-summary__entry")
      end
      expect(page).to have_selector("#{row(complete_song)} .song-part-summary__item--filled .song-part-summary__entry[data-join-part-id='#{complete_drums.id}']")
      expect(page).to have_no_selector("#{row(band_song)} .song-part-summary__entry")
    end

    it "楽曲欄は地図のすぐ下にあり、右下の「参加する」が固定表示される" do
      expect(songs_section_follows_map?).to be true
      fab = page.evaluate_script(<<~JS)
        (function () {
          var rect = document.querySelector('.event-join-fab__button').getBoundingClientRect();
          return { position: getComputedStyle(document.querySelector('.event-join-fab')).position,
                   right: window.innerWidth - rect.right, bottom: window.innerHeight - rect.bottom, height: rect.height };
        })()
      JS
      expect(fab["position"]).to eq "fixed"
      expect(fab["right"]).to be_between(8, 40)
      expect(fab["bottom"]).to be_between(8, 40)
      expect(fab["height"]).to be >= 44
      screenshot("10_mobile_fab", scroll_to: "#map")
    end

    it "右下の「参加する」は未選択なら案内だけ出し、選んだ分だけを確認画面へ送る(登録はしない)" do
      page.execute_script("document.querySelector('.event-join-fab__button').click()")
      expect(page).to have_selector(".event-join-fab__hint", text: "参加する曲・パートを選んでください", visible: true)
      expect(page).to have_current_path(public_event_path(event))

      tap_chip(open_song, open_vocal)
      tap_chip(open_song, open_other)
      tap_chip(second_song, second_bass)
      tap_chip(open_song, open_other)
      expect(page).to have_no_selector(".event-join-fab__hint", visible: true)
      expect(page).to have_selector(".event-join-fab__count", text: "2", visible: true)
      screenshot("11_mobile_fab_selected", scroll_to: row(second_song))

      accept_confirm("参加申請しますか？") do
        page.execute_script("document.querySelector('.event-join-fab__button').click()")
      end
      expect(page).to have_content("【#{open_song.song_name}】の曲に【Vocal】で参加！", wait: 10)
      expect(page).to have_content("【#{second_song.song_name}】の曲に【Bass】で参加！")
      expect(page).to have_no_content("【Other】で参加！")
      expect(page).to have_selector(".confirm-index", count: 2)
      expect(JoinPartCustomer.where(customer: member)).to be_empty
      screenshot("07_join_confirm_two_parts", scroll_to: "body")
    end

    it "担当者のいる「Dr 1人参加 追加可」を選んで確認画面を経て登録すると、既存の担当者も残る" do
      tap_chip(complete_song, complete_drums)
      expect(page).to have_current_path(public_event_path(event))
      accept_confirm("参加申請しますか？") do
        page.execute_script("document.querySelector('.event-join-fab__button').click()")
      end
      expect(page).to have_content("【#{complete_song.song_name}】の曲に【Drums】で参加！", wait: 10)
      expect(JoinPartCustomer.where(customer: member)).to be_empty

      accept_confirm("参加申請しますか？") { click_button "参加する" }
      expect(page).to have_content("イベントへの参加が完了しました", wait: 10)
      expect(complete_drums.reload.customers).to contain_exactly(drummer, member)
      expect(page).to have_selector("#{row(complete_song)} .song-part-summary__item--filled", text: /\ADr\s+2人参加\z/)
      expect(page).to have_no_selector("#{row(complete_song)} .song-part-summary__entry")
    end

    it "バンド出演枠は初期折りたたみで、バンドごとに開閉・応援できる" do
      panel = "#event-band-#{band.id}"
      expect(page).to have_selector("#{panel} .event-band-panel__name", text: "固定バンド", visible: true)
      expect(page).to have_selector("#{panel} .event-band-panel__toggle[aria-expanded='false']", text: "詳細", visible: true)
      expect(page).to have_no_selector("#{panel} .event-band-panel__members", visible: true)
      screenshot("08_band_collapsed", scroll_to: "#event-bands")

      page.execute_script("document.querySelector('#{panel} .event-band-panel__toggle').click()")
      expect(page).to have_selector("#{panel} .event-band-panel__members", text: "ドラム会員", visible: true)
      expect(page).to have_selector("#{panel} .event-band-panel__song-list", text: "バンドの曲", visible: true)
      expect(page).to have_selector("#{panel} .song-cheer__count", text: "0", visible: true)
      screenshot("09_band_opened", scroll_to: "#event-bands")

      page.execute_script("document.querySelector('#{panel} .event-band-panel__toggle').click()")
      expect(page).to have_no_selector("#{panel} .event-band-panel__members", visible: true)

      page.execute_script("document.querySelector('#{panel} .event-band-panel__toggle').click()")
      page.execute_script("document.querySelector('#{panel} .song-cheer__button').click()")
      expect(page).to have_content("「固定バンド」を応援しました📣", wait: 10)
      expect(EventBandCheer.where(event_band: band, customer: member).count).to eq 1
      page.execute_script("document.querySelector('#{panel} .event-band-panel__toggle').click()")
      expect(page).to have_selector("#{panel} .song-cheer__count", text: "1", visible: true)
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
    expect(page).to have_selector("#event-band-#{band.id} .event-band-panel__members", text: "ドラム会員", visible: true)
    expect(page).to have_no_selector(".event-band-panel__toggle", visible: true)
    expect(page).to have_no_selector(".event-join-fab", visible: true)
    expect(page).to have_button("参加確認画面へ", disabled: true)
    expect(songs_section_follows_map?).to be true
    screenshot("05_pc_table", scroll_to: "#map")

    check_part(open_vocal)
    check_part(second_bass)
    expect(page).to have_button("参加確認画面へ", disabled: false)
    accept_confirm("参加申請しますか？") { click_button "参加確認画面へ" }
    expect(page).to have_content("【#{open_song.song_name}】の曲に【Vocal】で参加！", wait: 10)
    expect(page).to have_content("【#{second_song.song_name}】の曲に【Bass】で参加！")
  end

  it "開催コミュニティに所属していない人には、一覧からの申込ボタンを出さない" do
    sign_in_via_form(outsider)
    use_mobile_viewport(width: 375, height: 812)
    visit public_event_path(event)

    expect(page).to have_selector("#{row(open_song)} .song-part-summary__item--open", visible: true, wait: 10)
    expect(page).to have_no_selector(".song-part-summary__entry")
    expect(page).to have_no_selector(".event-join-fab")
    # 申込できない人には従来どおり参加フォームを出し、送信時にサーバー側で案内する。
    expect(page).to have_selector("#submit_join_form", visible: true)
  end
end
