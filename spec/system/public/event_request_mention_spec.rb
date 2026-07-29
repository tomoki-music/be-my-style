require "rails_helper"

# イベントリクエスト欄(#input_request、input[type="text"])へ既存チャットの
# @メンションAutocomplete(chat_mention_autocomplete.js)をそのまま接続した結果を
# 実ブラウザで検証する。
#
# 注記: このheadless Chrome環境では、このイベント詳細画面上のどの要素であっても
# (本PRと無関係な既存の送信ボタン等も含め)Seleniumの実クリックがDOMフォーカスを
# 移動させない現象を確認済み(mainブランチでも再現する既存の環境制約であり、本PRの
# 変更が原因ではない)。そのため、event_request_youtube_card_spec.rbの既存手法
# (fill_in_request_input、page.execute_scriptでvalue設定+Eventディスパッチ)と同じ
# 「実フォーカスに依存せずDOMイベントを直接発火させる」方式で、chat_mention_autocomplete.jsの
# 入力検知(input)・候補選択(mousedown)・キー操作(keydown)の各リスナーを直接検証する。
# これらのリスナーはtextarea/input特有のAPIを使わず.value/.selectionStart/.selectionEnd/
# addEventListenerのみに依存するため、実フォーカスの有無に関わらず同じコードパスを検証できる。
RSpec.describe "イベントリクエストの@メンション", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:owner) { create(:customer, :customer_with_parts) }
  let(:community) { create(:community) }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }
  let(:song) { event.songs.first }
  let(:join_part_a) { create(:join_part, song: song) }
  let(:join_part_b) { create(:join_part, song: song) }
  let(:poster) { create(:customer, name: "投稿花子") }
  let(:participant) { create(:customer, name: "参加太郎") }

  before do
    owner.create_subscription!(status: "active", plan: "core")
    owner.update!(onboarding_done: true)
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: poster, community: community)
    CommunityCustomer.find_or_create_by!(customer: participant, community: community)

    create(:join_part_customer, join_part: join_part_a, customer: poster)
    create(:join_part_customer, join_part: join_part_b, customer: participant)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def submit_request_form
    page.execute_script("window.confirm = function() { return true; };")
    page.execute_script("document.querySelector('.event-request-btn').click();")
  end

  # 実フォーカスに依存せず、input要素へ直接キー入力相当のinputイベントを発火させる
  def type_into_input_request(text)
    page.execute_script(<<~JS)
      (function () {
        var el = document.querySelector('#input_request');
        el.value = #{text.to_json};
        el.selectionStart = el.selectionEnd = el.value.length;
        el.dispatchEvent(new Event('input'));
      })();
    JS
  end

  def dispatch_mousedown(selector)
    page.execute_script(<<~JS)
      (function () {
        var el = document.querySelector(#{selector.to_json});
        if (!el) return;
        el.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true }));
      })();
    JS
  end

  def dispatch_keydown(key)
    page.execute_script(<<~JS)
      (function () {
        var el = document.querySelector('#input_request');
        el.dispatchEvent(new KeyboardEvent('keydown', { key: #{key.to_json}, bubbles: true, cancelable: true }));
      })();
    JS
  end

  it "input[type=text]の#input_requestは@入力で候補ドロップダウン(ALL+イベント参加者)を表示すること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    input = find("#input_request", visible: :all)
    expect(input.tag_name).to eq("input")
    expect(input[:type]).to eq("text")

    type_into_input_request("@")

    expect(page).to have_selector(".mention-autocomplete-item", text: "ALL", wait: 10)
    expect(page).to have_selector(".mention-autocomplete-item", text: participant.name)
  end

  it "参加していないCustomerは候補ドロップダウンに表示されないこと" do
    outsider = create(:customer, name: "未参加者")
    CommunityCustomer.find_or_create_by!(customer: outsider, community: community)

    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", wait: 10)

    expect(page).not_to have_selector(".mention-autocomplete-item", text: outsider.name)
  end

  it "候補をmousedown(クリック・タップ相当)で選択すると、本文へ内部記法として送信され、表示側でメンション化されること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", text: participant.name, wait: 10)

    dispatch_mousedown(".mention-autocomplete-item:nth-child(2)")

    expect(page).to have_field("input_request", with: "@#{participant.name} ")

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
    expect(Notification.where(visited_id: participant.id, action: "request-msg")).to be_empty
  end

  it "@ALLを選択して投稿すると、現在の参加者(投稿者以外)全員へメンション通知が作成されること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", text: "ALL", wait: 10)

    dispatch_mousedown(".mention-autocomplete-item:nth-child(1)") # ALLは先頭

    expect(page).to have_field("input_request", with: "@ALL ")

    submit_request_form

    expect(page).to have_selector(".chat-mention--all", wait: 10)
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
    expect(Notification.where(visited_id: poster.id)).to be_empty
  end

  it "ArrowDown/Enterのキー操作で候補を選択できること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", text: "ALL", wait: 10)

    dispatch_keydown("ArrowDown") # ALL(先頭)からparticipantへ移動
    dispatch_keydown("Enter")

    expect(page).to have_field("input_request", with: "@#{participant.name} ")
  end

  it "Escapeで候補ドロップダウンを閉じられること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", wait: 10)

    dispatch_keydown("Escape")
    expect(page).not_to have_selector(".mention-autocomplete-item")
  end

  context "モバイル幅(375x812)" do
    before { page.current_window.resize_to(375, 812) }

    it "候補ドロップダウンがモバイル幅でも表示され、mousedownで選択できること" do
      sign_in_via_form(poster)
      visit public_event_path(event)

      type_into_input_request("@")
      expect(page).to have_selector(".mention-autocomplete-item", text: participant.name, wait: 10)

      dropdown_width = page.evaluate_script("document.querySelector('.mention-autocomplete').getBoundingClientRect().width")
      client_width = page.evaluate_script("document.documentElement.clientWidth")
      expect(dropdown_width).to be <= client_width + 1

      dispatch_mousedown(".mention-autocomplete-item:nth-child(2)")
      expect(page).to have_field("input_request", with: "@#{participant.name} ")
    end
  end
end
