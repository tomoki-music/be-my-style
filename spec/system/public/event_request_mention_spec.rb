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
  let(:member_not_participating) { create(:customer, name: "興味花子") }

  before do
    owner.create_subscription!(status: "active", plan: "core")
    owner.update!(onboarding_done: true)
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: poster, community: community)
    CommunityCustomer.find_or_create_by!(customer: participant, community: community)
    CommunityCustomer.find_or_create_by!(customer: member_not_participating, community: community)

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

  # 候補行のテキスト内容(表示名)で対象を特定してmousedown(クリック・タップ相当)を発火させる。
  # 候補の並び順(name順ソート)はロケール/コレーションに依存するため、
  # nth-childのような位置指定ではなく表示名で対象を特定する。
  def dispatch_mousedown_for(text)
    page.execute_script(<<~JS)
      (function () {
        var items = document.querySelectorAll('.mention-autocomplete-item');
        for (var i = 0; i < items.length; i++) {
          if (items[i].textContent.indexOf(#{text.to_json}) !== -1) {
            items[i].dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true }));
            return;
          }
        }
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

  it "イベント未参加でも開催元コミュニティのメンバーであれば候補ドロップダウンに表示されること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")

    expect(page).to have_selector(".mention-autocomplete-item", text: member_not_participating.name, wait: 10)
  end

  it "開催元コミュニティに参加していないCustomerは候補ドロップダウンに表示されないこと" do
    outsider = create(:customer, name: "他コミュニティ太郎")
    other_community = create(:community)
    CommunityCustomer.find_or_create_by!(customer: outsider, community: other_community)

    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", wait: 10)

    expect(page).not_to have_selector(".mention-autocomplete-item", text: outsider.name)
  end

  it "開催元コミュニティのメンバー(イベント未参加)を選択して投稿すると、メンション通知が作成されること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", text: member_not_participating.name, wait: 10)

    dispatch_mousedown_for(member_not_participating.name)
    expect(page).to have_field("input_request", with: "@#{member_not_participating.name} ")

    submit_request_form
    expect(page).to have_selector(".chat-mention", text: "@#{member_not_participating.name}", wait: 10)

    notification = Notification.find_by(visited_id: member_not_participating.id, action: "mention_request")
    expect(notification).to be_present
  end

  # 上記シナリオのメンション対象者本人としてサインインし、通知一覧の表示・遷移を確認する
  # (同一テスト内でのユーザー切り替えはログアウト操作がこの環境で不安定なため、
  # 通知は直接作成してクリーンなセッションで検証する)。
  it "通知一覧にmention_request通知が「メンションしました」と表示され、クリックでイベント詳細へ遷移すること" do
    member_not_participating.create_notification_mention_request(poster, event.id)

    sign_in_via_form(member_not_participating)
    visit public_notifications_path

    expect(page).to have_content("メンションしました", wait: 10)
    expect(page).to have_content(event.event_name)

    click_link event.event_name
    expect(page).to have_current_path(public_event_path(event), wait: 10)
  end

  it "候補をmousedown(クリック・タップ相当)で選択すると、本文へ内部記法として送信され、表示側でメンション化されること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", text: participant.name, wait: 10)

    dispatch_mousedown_for(participant.name)

    expect(page).to have_field("input_request", with: "@#{participant.name} ")

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
    expect(Notification.where(visited_id: participant.id, action: "request-msg")).to be_empty
  end

  it "@ALLを選択して投稿すると、開催元コミュニティの有効メンバー(投稿者以外、イベント未参加者も含む)全員へメンション通知が作成されること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", text: "ALL", wait: 10)

    dispatch_mousedown_for("ALL")

    expect(page).to have_field("input_request", with: "@ALL ")

    submit_request_form

    expect(page).to have_selector(".chat-mention--all", wait: 10)
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
    expect(Notification.where(visited_id: member_not_participating.id, action: "mention_request")).to be_present
    expect(Notification.where(visited_id: poster.id)).to be_empty
  end

  it "ArrowDown/Enterのキー操作で候補を選択できること" do
    sign_in_via_form(poster)
    visit public_event_path(event)

    type_into_input_request("@")
    expect(page).to have_selector(".mention-autocomplete-item", text: "ALL", wait: 10)

    # 候補の並び順(name順ソート)はロケール/コレーションに依存するため、2番目の候補名を
    # 動的に取得してから検証する(ALLが先頭であることのみ固定で仮定する)。
    second_item_name = page.evaluate_script(
      "document.querySelector('.mention-autocomplete-item:nth-child(2) .mention-autocomplete-display-name').textContent"
    )

    dispatch_keydown("ArrowDown") # ALL(先頭)から2番目の候補へ移動
    dispatch_keydown("Enter")

    expect(page).to have_field("input_request", with: "@#{second_item_name} ")
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

      dispatch_mousedown_for(participant.name)
      expect(page).to have_field("input_request", with: "@#{participant.name} ")
    end

    it "イベント未参加の開催元コミュニティメンバーも候補に表示され、mousedownで選択できること" do
      sign_in_via_form(poster)
      visit public_event_path(event)

      type_into_input_request("@")
      expect(page).to have_selector(".mention-autocomplete-item", text: member_not_participating.name, wait: 10)

      dropdown_width = page.evaluate_script("document.querySelector('.mention-autocomplete').getBoundingClientRect().width")
      client_width = page.evaluate_script("document.documentElement.clientWidth")
      expect(dropdown_width).to be <= client_width + 1

      dispatch_mousedown_for(member_not_participating.name)
      expect(page).to have_field("input_request", with: "@#{member_not_participating.name} ")
    end
  end
end
