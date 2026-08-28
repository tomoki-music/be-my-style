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

  def check_via_js(id)
    page.execute_script("document.getElementById(#{id.to_json}).checked = true")
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

  it "選択できる候補がいれば送信ボタンは有効" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)

    expect(page).to have_selector("#entry-invitation-form .js-entry-invitation-submit:not([disabled])")
    expect(page).not_to have_content("現在、依頼できる演奏経験者はいません")
  end

  it "選択できる候補が0人なら送信ボタンは disabled で補足文を表示する" do
    # 経験者(experienced_a / experienced_b)がいる Vocal / Guitar の両パートに
    # 現役参加者を入れて募集終了にし、選択できる候補を0人にする。
    [current_vocal, current_guitar].each do |part|
      joiner = create(:customer)
      CommunityCustomer.find_or_create_by!(customer: joiner, community: community)
      create(:join_part_customer, join_part: part, customer: joiner)
    end

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

  it "未選択で送信すると警告が出て遷移しない" do
    sign_in_via_form(owner)
    visit public_event_path(current_event)
    expect(page).to have_selector("#entry-invitation-form")

    message = accept_alert { submit_form }

    expect(message).to include "選択"
    expect(page).to have_selector("#entry-invitation-form")
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
end
