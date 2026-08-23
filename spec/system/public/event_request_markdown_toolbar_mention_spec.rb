require "rails_helper"

# みんなのリクエスト欄のMarkdown入力補助ツールバー(request_markdown_toolbar.js)と、
# 既存の@メンションオートコンプリート(chat_mention_autocomplete.js)の組み合わせを検証する。
#
# 背景: 以前の実装は、選択範囲を装飾済み文字列へ「まとめて1回で置換」していたため、
# chat_mention_autocomplete.jsの位置トラッキング(diffAndAdjustMentions、textareaのinput
# イベントごとに直前値との文字列差分から編集区間を検出し、その区間に重なるメンションを
# 解除する)から見て「メンション本体を含む区間がまるごと編集された」と判定され、
# メンションのトラッキングが解除されてしまっていた(投稿後にメンションがリンク化されない・
# 通知も作成されない)。
#
# 修正後は、選択文字列(メンション本体を含みうる)自体は書き換えず、記号だけを
# 選択範囲の外側(前後/各行頭)へ個別に挿入し、挿入のたびにinputイベントを発火することで、
# chat_mention_autocomplete.js側に「メンション本体に重ならない小さな挿入」として
# 認識させている。本specはこの回復を検証する(request_markdown_toolbar.js側のみの修正で、
# chat_mention_autocomplete.js自体は変更していない)。
RSpec.describe "みんなのリクエストのMarkdown入力補助ツールバーと@メンションの共存", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:owner) { create(:customer, :customer_with_parts) }
  let(:community) { create(:community) }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }
  let(:song) { event.songs.first }
  let(:poster) { create(:customer, name: "投稿花子") }
  let(:participant) { create(:customer, name: "参加太郎") }
  let(:participant2) { create(:customer, name: "参加次郎") }

  before do
    owner.create_subscription!(status: "active", plan: "core")
    owner.update!(onboarding_done: true)
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: poster, community: community)
    CommunityCustomer.find_or_create_by!(customer: participant, community: community)
    CommunityCustomer.find_or_create_by!(customer: participant2, community: community)

    create(:join_part_customer, join_part: create(:join_part, song: song), customer: participant)
    create(:join_part_customer, join_part: create(:join_part, song: song), customer: participant2)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  # textareaの値を丸ごと指定し、カーソルを末尾へ置いてinputイベントを発火する
  # (event_request_mention_spec.rbのtype_into_input_requestと同じ手法)。
  # 複数メンションを組み立てる際は、直前の値を含めた「最終的な全文」を毎回明示的に渡す
  # (実際のタイピングの積み重ねを模した、丸ごと置換の繰り返しとして扱う)。
  def type_full_value(text)
    page.execute_script(<<~JS)
      (function () {
        var el = document.querySelector('#input_request');
        el.value = #{text.to_json};
        el.selectionStart = el.selectionEnd = el.value.length;
        el.dispatchEvent(new Event('input'));
      })();
    JS
  end

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

  # 候補ドロップダウンから選択し、選択後のtextarea値を返す(表示名の長さは候補ごとに
  # 異なるため、呼び出し元でハードコードせずここから受け取る)。
  def pick_mention_candidate(name)
    expect(page).to have_selector(".mention-autocomplete-item", text: name, wait: 10)
    dispatch_mousedown_for(name)
    request_textarea_value
  end

  def set_selection(start_pos, end_pos)
    page.execute_script(<<~JS)
      (function () {
        var el = document.querySelector('#input_request');
        el.focus();
        el.selectionStart = #{start_pos};
        el.selectionEnd = #{end_pos};
      })();
    JS
  end

  def click_toolbar_button(action)
    page.execute_script(<<~JS)
      document.querySelector('.request-markdown-toolbar__btn[data-md-action="#{action}"]').click();
    JS
  end

  def request_textarea_value
    page.evaluate_script("document.querySelector('#input_request').value")
  end

  def submit_request_form
    page.execute_script("window.confirm = function() { return true; };")
    page.execute_script("document.querySelector('.event-request-btn').click();")
  end

  def visit_event_page(customer)
    sign_in_via_form(customer)
    visit public_event_path(event)
  end

  # 1. メンションだけを投稿すると、従来どおりリンク化される(回帰確認・ベースライン)。
  it "メンションのみの投稿は従来どおりリンク化され、通知も作成される" do
    visit_event_page(poster)

    type_full_value("@#{participant.name}")
    pick_mention_candidate(participant.name)
    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
  end

  # 2. メンションを含む文字列全体を太字にしても、メンションがリンク化される。
  #
  # 候補選択で挿入される表示は必ず末尾に半角スペースを含む("@名前 ")ため、選択範囲を
  # そのまま**で囲むと閉じ側の**の直前が空白になる。これはRedcarpet(既存の共通Markdown
  # 処理)の一般的な仕様で、閉じ側直前が空白の強調はstrongとして展開されない
  # (太字自体は既存のプレースホルダー挿入等でも同じ挙動であり、本修正の対象外・
  # 今回の目的を超えるためここでは変更しない)。そのためこのテストでは<strong>タグの
  # 有無ではなく、本題である「メンションのトラッキングが失われないこと」を確認する。
  it "メンションを含む文字列全体を太字にしても、メンションがリンク化され通知も作成される" do
    visit_event_page(poster)

    type_full_value("@#{participant.name}")
    value = pick_mention_candidate(participant.name)

    set_selection(0, value.length)
    click_toolbar_button("bold")
    expect(request_textarea_value).to eq("**#{value}**")

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
  end

  # 3. メンションを含む行を見出しにしても、メンションがリンク化される。
  it "メンションを含む行を見出しにしても、メンションがリンク化され通知も作成される" do
    visit_event_page(poster)

    type_full_value("@#{participant.name}")
    pick_mention_candidate(participant.name)

    set_selection(0, 0) # 見出しは行頭挿入のみのため、カーソルが行内にあれば選択は不要
    click_toolbar_button("heading")
    expect(request_textarea_value).to start_with("## ")

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(page).to have_selector("h2")
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
  end

  # 4. メンションを含む複数行を箇条書きにしても、メンションがリンク化される。
  it "メンションを含む複数行を箇条書きにしても、両方のメンションがリンク化される" do
    visit_event_page(poster)

    type_full_value("@#{participant.name}")
    value1 = pick_mention_candidate(participant.name)

    type_full_value("#{value1}\n@#{participant2.name}")
    full_value = pick_mention_candidate(participant2.name)

    set_selection(0, full_value.length)
    click_toolbar_button("unordered-list")
    expect(request_textarea_value).to eq(full_value.split("\n").map { |l| "- #{l}" }.join("\n"))

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(page).to have_selector(".chat-mention", text: "@#{participant2.name}")
    expect(page).to have_selector("li", minimum: 2)
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
    expect(Notification.where(visited_id: participant2.id, action: "mention_request")).to be_present
  end

  # 5. メンションを含む複数行を番号リストにしても、メンションがリンク化される。
  it "メンションを含む複数行を番号リストにしても、両方のメンションがリンク化される" do
    visit_event_page(poster)

    type_full_value("@#{participant.name}")
    value1 = pick_mention_candidate(participant.name)

    type_full_value("#{value1}\n@#{participant2.name}")
    full_value = pick_mention_candidate(participant2.name)

    set_selection(0, full_value.length)
    click_toolbar_button("ordered-list")
    expect(request_textarea_value).to eq(full_value.split("\n").each_with_index.map { |l, i| "#{i + 1}. #{l}" }.join("\n"))

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(page).to have_selector(".chat-mention", text: "@#{participant2.name}")
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
    expect(Notification.where(visited_id: participant2.id, action: "mention_request")).to be_present
  end

  # 6. メンションを含む複数行を引用にしても、メンションがリンク化される。
  it "メンションを含む複数行を引用にしても、両方のメンションがリンク化される" do
    visit_event_page(poster)

    type_full_value("@#{participant.name}")
    value1 = pick_mention_candidate(participant.name)

    type_full_value("#{value1}\n@#{participant2.name}")
    full_value = pick_mention_candidate(participant2.name)

    set_selection(0, full_value.length)
    click_toolbar_button("quote")
    expect(request_textarea_value).to eq(full_value.split("\n").map { |l| "> #{l}" }.join("\n"))

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(page).to have_selector(".chat-mention", text: "@#{participant2.name}")
  end

  # 7. メンションを含む文字列へリンク操作を行った場合の挙動。
  # メンション表示名自体をリンクラベルにする操作は一般的な用途ではないが、
  # 少なくとも「メンションのトラッキングが失われない(投稿後も.chat-mentionとして残る)」
  # ことを確認する。
  it "メンションを含む文字列を選択してリンク化しても、メンションのトラッキングが失われない" do
    visit_event_page(poster)

    type_full_value("@#{participant.name}")
    value = pick_mention_candidate(participant.name)

    set_selection(0, value.length)
    click_toolbar_button("link")
    expect(request_textarea_value).to eq("[#{value}](https://)")

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
  end

  # 8. 1つの文章に複数メンションがあっても、それぞれ維持される(同一行内に複数メンションが
  # ある場合を明示的に確認する。4〜6は行またぎの複数メンションで確認済み)。
  it "同一行内の複数メンションを含めて太字にしても、両方のメンションがリンク化される" do
    visit_event_page(poster)

    type_full_value("@#{participant.name}")
    value1 = pick_mention_candidate(participant.name)

    # "@"の直前が空白(または行頭)でないと候補が開かない仕様(detectMentionTrigger)のため、
    # 2つ目のメンションの前には半角スペースを置く。
    type_full_value("#{value1}と #{"@#{participant2.name}"}")
    value_all = pick_mention_candidate(participant2.name)

    set_selection(0, value_all.length)
    click_toolbar_button("bold")
    expect(request_textarea_value).to eq("**#{value_all}**")

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(page).to have_selector(".chat-mention", text: "@#{participant2.name}")
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
    expect(Notification.where(visited_id: participant2.id, action: "mention_request")).to be_present
  end

  # 9. メンションより前だけを装飾しても位置がずれない。
  it "メンションより前のテキストだけを太字にしても、メンションの位置がずれずリンク化される" do
    visit_event_page(poster)

    # "@"の直前が空白(または行頭)でないと候補が開かない仕様のため、間に半角スペースを置く。
    type_full_value("前置き #{"@#{participant.name}"}")
    full_value = pick_mention_candidate(participant.name)

    # 「前置き」部分(メンションより前)だけを選択する
    set_selection(0, "前置き".length)
    click_toolbar_button("bold")
    expect(request_textarea_value).to eq("**前置き**" + full_value.sub("前置き", ""))

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(page).to have_selector("strong", text: "前置き")
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
  end

  # 10. メンションより後だけを装飾しても位置がずれない。
  it "メンションより後のテキストだけを太字にしても、メンションの位置がずれずリンク化される" do
    visit_event_page(poster)

    type_full_value("@#{participant.name}")
    value = pick_mention_candidate(participant.name)

    type_full_value("#{value}お願いします")

    set_selection(value.length, request_textarea_value.length)
    click_toolbar_button("bold")
    expect(request_textarea_value).to eq("#{value}**お願いします**")

    submit_request_form

    expect(page).to have_selector(".chat-mention", text: "@#{participant.name}", wait: 10)
    expect(page).to have_selector("strong", text: "お願いします")
    expect(Notification.where(visited_id: participant.id, action: "mention_request")).to be_present
  end

  # 11. メンションを含まない通常のMarkdown操作は従来どおり動作する(回帰確認)。
  it "メンションを含まない通常の太字・箇条書き操作は従来どおり動作する" do
    visit_event_page(poster)

    type_full_value("テスト")
    set_selection(0, 3)
    click_toolbar_button("bold")
    expect(request_textarea_value).to eq("**テスト**")

    type_full_value("曲A\n曲B")
    set_selection(0, request_textarea_value.length)
    click_toolbar_button("unordered-list")
    expect(request_textarea_value).to eq("- 曲A\n- 曲B")
  end
end
