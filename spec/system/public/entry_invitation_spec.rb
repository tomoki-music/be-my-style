require "rails_helper"

# 演奏経験者へのエントリー依頼UI(楽曲表統合版)。
# 見出し・送信ボタン・確認画面へのGETフォーム(#entry-invitation-form)は楽曲表の外の
# <td> に置き、対象者のチェックボックスは楽曲表の各パート欄に置いて form= 属性で紐付ける。
# 曲・パートをまたいで候補を選び、1 回の操作で確認画面へ進む。モバイル横スクロール回帰防止も兼ねる。
#
# 注記: event_request_markdown_toolbar_spec.rb と同じ理由(このheadless Chrome環境では
# Seleniumの実クリック/checkがDOMへ反映されない既知の環境制約)により、
# チェック操作・送信は page.execute_script で直接行う。
# レイアウト検証は CDP Emulation.setDeviceMetricsOverride 方式。
RSpec.describe "エントリー依頼UI（PC/スマホ）", type: :system do
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

  # 実ユーザーの操作と同じく change を発火させ、ボタン状態同期を動かす。
  def check_via_js(id)
    page.execute_script(<<~JS)
      (function () {
        var cb = document.getElementById(#{id.to_json});
        cb.checked = true;
        cb.dispatchEvent(new Event('change', { bubbles: true }));
      })()
    JS
  end

  def uncheck_via_js(id)
    page.execute_script(<<~JS)
      (function () {
        var cb = document.getElementById(#{id.to_json});
        cb.checked = false;
        cb.dispatchEvent(new Event('change', { bubbles: true }));
      })()
    JS
  end

  def check_join_part_via_js(part)
    page.execute_script(<<~JS)
      (function () {
        var cb = document.getElementById('event_join_part_ids_#{part.id}');
        cb.checked = true;
        cb.dispatchEvent(new Event('change', { bubbles: true }));
      })()
    JS
  end

  def uncheck_join_part_via_js(part)
    page.execute_script(<<~JS)
      (function () {
        var cb = document.getElementById('event_join_part_ids_#{part.id}');
        cb.checked = false;
        cb.dispatchEvent(new Event('change', { bubbles: true }));
      })()
    JS
  end

  def join_submit_disabled?
    page.evaluate_script("document.getElementById('submit_join_form').disabled")
  end

  def invitation_submit_disabled?
    page.evaluate_script("document.querySelector('#entry-invitation-form .js-entry-invitation-submit').disabled")
  end

  def submit_form
    page.execute_script("document.querySelector('#entry-invitation-form .js-entry-invitation-submit').click()")
  end

  def expect_submit_area_within_viewport
    overflow = page.evaluate_script(<<~JS)
      (function () {
        var form = document.querySelector('#entry-invitation-form');
        if (!form) return null;
        var clientWidth = document.documentElement.clientWidth;
        var maxRight = form.getBoundingClientRect().right;
        form.querySelectorAll('*').forEach(function (el) {
          var right = el.getBoundingClientRect().right;
          if (right > maxRight) maxRight = right;
        });
        return maxRight - clientWidth;
      })()
    JS
    expect(overflow).to be <= 1
  end

  [320, 375, 414].each do |width|
    it "#{width}px幅で送信フォーム(送信ボタン)が画面外にはみ出さず、スマホ向け操作案内が表示される" do
      sign_in_via_form(owner)
      set_mobile_viewport(width)
      visit public_event_path(current_event)

      expect(page).to have_selector("#entry-invitation-form")
      expect_submit_area_within_viewport
      expect(page).to have_selector(".entry-invitation-form__mobile-hint", visible: true)
      expect(page).to have_content("楽曲表を横にスクロールして")
    end
  end

  it "ページ内の送信ボタンは 1 つだけ" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector(".js-entry-invitation-submit", count: 1)
  end

  it "form.elements に form= 属性で紐付いた外部checkboxが含まれる" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector("#entry-invitation-form")

    included = page.evaluate_script(<<~JS)
      (function () {
        var form = document.getElementById('entry-invitation-form');
        return Array.prototype.some.call(form.elements, function (el) {
          return el.classList && el.classList.contains('js-entry-invitation-checkbox');
        });
      })()
    JS
    expect(included).to be true
  end

  it "checkbox の id と target token はページ内で一意" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)

    dup = page.evaluate_script(<<~JS)
      (function () {
        var ids = [], tokens = [];
        document.querySelectorAll('.js-entry-invitation-checkbox').forEach(function (cb) {
          ids.push(cb.id); tokens.push(cb.value);
        });
        function hasDup(a) { return a.length !== new Set(a).size; }
        return { ids: hasDup(ids), tokens: hasDup(tokens) };
      })()
    JS
    expect(dup["ids"]).to be false
    expect(dup["tokens"]).to be false
  end

  it "複数の曲・パートから選んだ人だけが 1 回の操作で確認画面に出る" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector("#entry-invitation-form")

    check_via_js(checkbox_id(current_song, current_vocal, experienced_a))
    check_via_js(checkbox_id(current_song, current_guitar, experienced_b))
    submit_form

    expect(page).to have_content("エントリー依頼の送信確認")
    expect(page).to have_content("経験Ａ")
    expect(page).to have_content("経験Ｂ")
    expect(page).to have_content("Vocal")
    expect(page).to have_content("Guitar")
    expect(page).to have_content("2人")
  end

  it "選択できる候補がいても、未選択の初期状態では送信ボタンは disabled" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)

    expect(page).to have_selector("#entry-invitation-form .js-entry-invitation-submit[disabled]")
    expect(page).not_to have_content("現在、依頼できる演奏経験者はいません")
  end

  it "有効な依頼候補を1件チェックすると送信ボタンが有効になる" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)

    expect(invitation_submit_disabled?).to be(true)
    check_via_js(checkbox_id(current_song, current_vocal, experienced_a))
    expect(invitation_submit_disabled?).to be(false)
  end

  it "選択できる候補が0人なら送信ボタンは disabled で補足文を表示する" do
    # 経験者(experienced_a / experienced_b)がいる Vocal / Guitar の両パートへ
    # 24時間以内に依頼済みにして、選択できる候補を0人にする。
    create(:entry_invitation, event: current_event, song: current_song, join_part: current_vocal,
                              customer: experienced_a, requested_by_customer: owner, sent_at: 1.hour.ago)
    create(:entry_invitation, event: current_event, song: current_song, join_part: current_guitar,
                              customer: experienced_b, requested_by_customer: owner, sent_at: 1.hour.ago)

    sign_in_via_form(owner)
    visit public_event_path(current_event)

    expect(page).to have_selector("#entry-invitation-form .js-entry-invitation-submit[disabled]")
    expect(page).to have_content("現在、依頼できる演奏経験者はいません")
  end

  it "PC幅ではスマホ向け操作案内が非表示になる(d-md-none)" do
    sign_in_via_form(owner)
    # モバイルテストと同じ CDP 方式で明示的にPC幅へ。直前の例が残した
    # DeviceMetricsOverride を上書きし、min-width:768px の media query を発火させる。
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: 1280, height: 900, deviceScaleFactor: 1, mobile: false
    )
    visit public_event_path(current_event)
    expect(page).to have_selector("#entry-invitation-form")

    display = page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector('.entry-invitation-form__mobile-hint');
        return el ? window.getComputedStyle(el).display : null;
      })()
    JS
    expect(display).to eq "none"
  end

  it "未選択のまま送信イベントが起きても警告が出て遷移しない(サーバー到達前の防御)" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector("#entry-invitation-form")

    # 通常は disabled でクリックできないが、DOM 改変等で submit された場合の JS 側防御を検証する。
    message = accept_alert do
      page.execute_script(<<~JS)
        (function () {
          var b = document.querySelector('#entry-invitation-form .js-entry-invitation-submit');
          b.disabled = false;
          b.click();
        })()
      JS
    end

    expect(message).to include "選択"
    expect(page).to have_selector("#entry-invitation-form")
    expect(page).to have_no_content("エントリー依頼の送信確認")
  end

  it "二重送信(連続クリック)を防ぐ" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    check_via_js(checkbox_id(current_song, current_vocal, experienced_a))

    submitting = page.evaluate_script(<<~JS)
      (function () {
        var form = document.getElementById('entry-invitation-form');
        var btn = form.querySelector('.js-entry-invitation-submit');
        form.addEventListener('submit', function (e) { e.preventDefault(); }, { once: false });
        btn.click();
        var first = btn.getAttribute('data-submitting');
        btn.click();
        return first;
      })()
    JS
    expect(submitting).to eq "1"
  end

  # Phase 3 状態表: 参加フォームとエントリー依頼フォームのボタン制御が完全に分離されていること。
  describe "参加ボタンと依頼ボタンの分離(状態表)" do
    before do
      sign_in_via_form(owner)
      visit public_event_path(current_event)
      expect(page).to have_selector("#entry-invitation-form")
      expect(page).to have_selector("#submit_join_form")
    end

    it "どちらも未選択: 両ボタン disabled" do
      expect(join_submit_disabled?).to be(true)
      expect(invitation_submit_disabled?).to be(true)
    end

    it "参加パートだけ選択: 参加ボタン enabled / 依頼ボタン disabled" do
      check_join_part_via_js(current_vocal)
      expect(join_submit_disabled?).to be(false)
      expect(invitation_submit_disabled?).to be(true)
    end

    it "経験者だけ選択: 参加ボタン disabled / 依頼ボタン enabled" do
      check_via_js(checkbox_id(current_song, current_vocal, experienced_a))
      expect(join_submit_disabled?).to be(true)
      expect(invitation_submit_disabled?).to be(false)
    end

    it "両方選択: 両ボタン enabled" do
      check_join_part_via_js(current_vocal)
      check_via_js(checkbox_id(current_song, current_guitar, experienced_b))
      expect(join_submit_disabled?).to be(false)
      expect(invitation_submit_disabled?).to be(false)
    end

    it "経験者を選択後に全解除: 依頼ボタン disabled / 参加ボタンは参加選択に従う" do
      check_join_part_via_js(current_vocal)
      check_via_js(checkbox_id(current_song, current_vocal, experienced_a))
      uncheck_via_js(checkbox_id(current_song, current_vocal, experienced_a))
      expect(invitation_submit_disabled?).to be(true)
      expect(join_submit_disabled?).to be(false)
    end

    it "参加パートを選択後に全解除: 参加ボタン disabled / 依頼ボタンは経験者選択に従う" do
      check_via_js(checkbox_id(current_song, current_vocal, experienced_a))
      check_join_part_via_js(current_vocal)
      uncheck_join_part_via_js(current_vocal)
      expect(join_submit_disabled?).to be(true)
      expect(invitation_submit_disabled?).to be(false)
    end

    it "依頼checkboxを選択した状態で参加フォームを強制submitしても targets[] が混入しない" do
      check_via_js(checkbox_id(current_song, current_vocal, experienced_a))

      params = page.evaluate_script(<<~JS)
        (function () {
          var form = document.getElementById('join_btn');
          var fd = new FormData(form);
          var keys = [];
          fd.forEach(function (_v, k) { keys.push(k); });
          return keys;
        })()
      JS
      expect(params).not_to include("targets[]")
    end

    it "参加checkboxを選択した状態で依頼フォームを送信しても event[join_part_ids][] が混入しない" do
      check_join_part_via_js(current_vocal)
      check_via_js(checkbox_id(current_song, current_vocal, experienced_a))

      params = page.evaluate_script(<<~JS)
        (function () {
          var form = document.getElementById('entry-invitation-form');
          var fd = new FormData(form);
          var keys = [];
          fd.forEach(function (_v, k) { keys.push(k); });
          return keys;
        })()
      JS
      expect(params).to include("targets[]")
      expect(params).not_to include("event[join_part_ids][]")
    end

    it "disabled 候補しかいない場合、依頼ボタンは有効化されない" do
      # experienced_a / experienced_b を Vocal / Guitar とも 24時間以内に依頼済みにする
      [current_vocal, current_guitar].each do |part|
        [experienced_a, experienced_b].each do |c|
          create(:entry_invitation, event: current_event, song: current_song, join_part: part,
                                    customer: c, requested_by_customer: owner, sent_at: 1.hour.ago)
        end
      end
      visit public_event_path(current_event)

      expect(page).to have_no_selector(".js-entry-invitation-checkbox")
      expect(invitation_submit_disabled?).to be(true)
    end

    it "pageshow(ブラウザバック相当)でボタン状態が再同期される" do
      check_via_js(checkbox_id(current_song, current_vocal, experienced_a))
      expect(invitation_submit_disabled?).to be(false)

      # checked 状態はそのままに pageshow だけ発火 → enabled のまま
      page.execute_script("window.dispatchEvent(new Event('pageshow'))")
      expect(invitation_submit_disabled?).to be(false)

      # 解除してから pageshow → disabled へ戻る
      uncheck_via_js(checkbox_id(current_song, current_vocal, experienced_a))
      page.execute_script("window.dispatchEvent(new Event('pageshow'))")
      expect(invitation_submit_disabled?).to be(true)
    end
  end

  # レイアウト崩れ回帰: 候補カード(役職バッジ・緑丸・disabled チェックボックス・
  # 状態ラベル・長い名前)と曲名セルの YouTube カードが、パート列(160px)/
  # 曲名列の内側に収まり、要素同士が重ならないことを bounding rect で確認する。
  describe "レイアウト崩れ回帰" do
    let(:long_name) { "演奏経験がとても豊富な山田太郎さんです" }
    let(:experienced_admin) { create(:customer, name: long_name, is_owner: :admin) }

    before do
      CommunityCustomer.find_or_create_by!(customer: experienced_admin, community: community)
      # 過去イベントの Vocal 経験者にする
      create(:join_part_customer, join_part: past_vocal, customer: experienced_admin)
      # 24時間以内に依頼済みにして disabled チェックボックス + 「依頼済み」ラベルを描画する
      create(:entry_invitation, event: current_event, song: current_song, join_part: current_vocal,
                                customer: experienced_admin, requested_by_customer: owner, sent_at: 1.hour.ago)
      # 最近アクティブ → 緑丸
      experienced_admin.update!(current_sign_in_at: Time.current)
      # 曲名セルに YouTube カードを出す
      current_song.update!(youtube_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    end

    def rects_for(selector_map_js)
      page.evaluate_script(<<~JS)
        (function () {
          function r(el) {
            if (!el) return null;
            var b = el.getBoundingClientRect();
            return { l: b.left, r: b.right, t: b.top, b: b.bottom, w: b.width, h: b.height };
          }
          #{selector_map_js}
        })()
      JS
    end

    def overlap?(a, b, tol = 1.0)
      return false if a.nil? || b.nil?
      a["l"] < b["r"] - tol && b["l"] < a["r"] - tol && a["t"] < b["b"] - tol && b["t"] < a["b"] - tol
    end

    it "PC幅: 候補カード各要素がセル内に収まり、役職バッジが名前・緑丸と重ならない" do
      sign_in_via_form(owner)
      page.driver.browser.execute_cdp(
        "Emulation.setDeviceMetricsOverride", width: 1280, height: 900, deviceScaleFactor: 1, mobile: false
      )
      visit public_event_path(current_event)
      expect(page).to have_selector(".entry-invitation-candidate--disabled", text: long_name)

      data = rects_for(<<~JS)
        var card = Array.prototype.find.call(
          document.querySelectorAll('.entry-invitation-candidate--disabled'),
          function (c) { return c.textContent.indexOf(#{long_name.to_json}) !== -1; }
        );
        var cell = card.closest('td');
        return {
          cell: r(cell),
          card: r(card),
          avatar: r(card.querySelector('.avatar-with-badge')),
          badge: r(card.querySelector('.avatar-role-badge')),
          dot: r(card.querySelector('.avatar-active-dot')),
          name: r(card.querySelector('.entry-invitation-candidate__name')),
          profile: r(card.querySelector('.entry-invitation-candidate__profile')),
          status: r(card.querySelector('.entry-invitation-candidate__status')),
          checkbox: r(card.querySelector('.entry-invitation-candidate__checkbox--disabled')),
          disabled: card.querySelector('.entry-invitation-candidate__checkbox--disabled').disabled
        };
      JS

      tol = 1.0
      # カードがパートセルの内側に収まる
      expect(data["card"]["l"]).to be >= data["cell"]["l"] - tol
      expect(data["card"]["r"]).to be <= data["cell"]["r"] + tol

      # アバター・役職バッジ・名前・プロフィールリンク・状態ラベル・チェックボックスがカード内
      %w[avatar badge dot name profile status checkbox].each do |k|
        expect(data[k]).not_to be_nil, "#{k} が描画されていない"
        expect(data[k]["l"]).to be >= data["card"]["l"] - tol, "#{k} がカード左外"
        expect(data[k]["r"]).to be <= data["card"]["r"] + tol, "#{k} がカード右外"
        expect(data[k]["t"]).to be >= data["card"]["t"] - tol, "#{k} がカード上外"
        expect(data[k]["b"]).to be <= data["card"]["b"] + tol, "#{k} がカード下外"
      end

      # 役職バッジと名前の矩形が重ならない / 緑丸と役職バッジの矩形が重ならない
      expect(overlap?(data["badge"], data["name"])).to be(false), "役職バッジと名前が重なっている"
      expect(overlap?(data["dot"], data["badge"])).to be(false), "緑丸と役職バッジが重なっている"

      # disabled チェックボックスが見えていて、選択できない
      expect(data["checkbox"]["w"]).to be > 0
      expect(data["checkbox"]["h"]).to be > 0
      expect(data["disabled"]).to be(true)
      expect(page).to have_content("依頼済み")
    end

    it "disabled チェックボックスはクリックしても選択されない" do
      sign_in_via_form(owner)
      visit public_event_path(current_event)
      expect(page).to have_selector(".entry-invitation-candidate__checkbox--disabled")

      checked = page.evaluate_script(<<~JS)
        (function () {
          var cb = document.querySelector('.entry-invitation-candidate__checkbox--disabled');
          cb.click();
          return cb.checked;
        })()
      JS
      expect(checked).to be(false)
    end

    it "PC幅: YouTubeカードが曲名セル幅に収まり、参加フォーム列へ侵入しない" do
      sign_in_via_form(owner)
      page.driver.browser.execute_cdp(
        "Emulation.setDeviceMetricsOverride", width: 1280, height: 900, deviceScaleFactor: 1, mobile: false
      )
      visit public_event_path(current_event)
      expect(page).to have_selector(".event-songs-table .event-song-youtube-card")

      data = rects_for(<<~JS)
        var card = document.querySelector('.event-songs-table .event-song-youtube-card');
        var cell = card.closest('td');
        var tds = cell.parentElement.querySelectorAll('td');
        return {
          card: r(card),
          cell: r(cell),
          img: r(card.querySelector('img')),
          link: r(card.closest('td').querySelector('.song-detail-link')),
          nextCell: r(tds[1])
        };
      JS

      # カード・曲名リンク・画像が曲名セルの幅を超えない(セル rect は罫線の collapse ぶん
      # ±数px 揺れるため幅で比較する)。
      expect(data["card"]["w"]).to be <= data["cell"]["w"] + 1
      expect(data["link"]["w"]).to be <= data["cell"]["w"] + 1
      expect(data["img"]["r"]).to be <= data["card"]["r"] + 1
      # 罫線の共有分(border-collapse)を許容しても、次列の内容へは食い込まない。
      expect(data["card"]["r"]).to be <= data["nextCell"]["l"] + 3, "YouTubeカードが参加フォーム列へ侵入している"
    end

    # イベント詳細ページには本変更以前から Bootstrap の .row / .col 由来で
    # 約15〜16px のページ横あふれがある(fbd1da3 で計測)。楽曲表の拡幅は
    # overflow-x:auto の .responsive-box 内で完結するため、この値を悪化させない。
    BASELINE_PAGE_OVERFLOW_PX = 16

    [320, 375, 414].each do |width|
      it "#{width}px幅: 楽曲表は .responsive-box 内だけで横スクロールし、ページ横スクロールを増やさない" do
        sign_in_via_form(owner)
        set_mobile_viewport(width)
        visit public_event_path(current_event)
        expect(page).to have_selector(".responsive-box")

        data = page.evaluate_script(<<~JS)
          (function () {
            var de = document.documentElement;
            var box = document.querySelector('.responsive-box');
            return {
              pageOverflow: de.scrollWidth - de.clientWidth,
              boxScrollable: box.scrollWidth - box.clientWidth,
              boxOverflowX: window.getComputedStyle(box).overflowX
            };
          })()
        JS

        # 楽曲表(min-width 1280px)は box 内で横スクロールできる
        expect(data["boxScrollable"]).to be > 0, "楽曲表が .responsive-box 内で横スクロールできない"
        expect(data["boxOverflowX"]).to eq("auto")
        # ページ全体の横スクロールは既存分(約16px)から悪化していない
        expect(data["pageOverflow"]).to be <= BASELINE_PAGE_OVERFLOW_PX + 2,
          "ページ横スクロールが既存分を超えて増えている(#{data['pageOverflow']}px / 既存 #{BASELINE_PAGE_OVERFLOW_PX}px)"
      end
    end
  end
end
