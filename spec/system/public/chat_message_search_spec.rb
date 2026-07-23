require "rails_helper"

# メッセージ検索機能を実ブラウザで検証する。既存のchat_quote_reply_spec.rb等と同じ方針
# (selenium_chrome_headless、フォームログイン)で、検索パネルの開閉・検索・
# 通常メッセージ/スレッド返信それぞれへのジャンプを確認する。
RSpec.describe "メッセージ検索機能", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }

  before do
    create(:chat_room_customer, chat_room: chat_room, customer: customer)
    create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def js_click(selector)
    page.evaluate_script("document.querySelector(#{selector.to_json}).click();")
  end

  def open_search_panel
    expect(page).to have_selector(".chat-search-trigger", wait: 10)
    js_click(".chat-search-trigger")
    expect(page).to have_selector("#search-panel:not([hidden])", wait: 10)
  end

  # chat_quote_reply_spec.rbのfill_in_markdown_textarea/js_clickと同じ理由(動的に表示される
  # パネル内の要素はCapybaraのネイティブfill_in・clickだとずれる/届かないことがある)で、
  # JSで直接valueを設定してinputイベントを発火させ、送信ボタンもjs_clickで押す。
  def search_for(keyword)
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.getElementById('search-panel-input');
        el.value = #{keyword.to_json};
        el.dispatchEvent(new Event('input'));
      })();
    JS
    js_click(".search-panel-submit")
  end

  it "検索パネルを開き、キーワード検索で一致するメッセージが一覧表示されること" do
    create(:chat_message, customer: other_customer, chat_room: chat_room, content: "明日のライブ楽しみです")
    create(:chat_message, customer: customer, chat_room: chat_room, content: "全然関係ない内容")

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)
    open_search_panel

    search_for("ライブ")

    within "#search-panel-body" do
      expect(page).to have_content("明日のライブ楽しみです", wait: 10)
      expect(page).not_to have_content("全然関係ない内容")
    end
  end

  it "1文字の検索語では実行されず文字数エラーが表示されること" do
    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)
    open_search_panel

    search_for("a")

    within "#search-panel-body" do
      expect(page).to have_content("2文字以上入力してください", wait: 10)
    end
  end

  it "検索結果(通常メッセージ)を選択すると、パネルが閉じて対象メッセージがハイライトされること" do
    target = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "明日のライブ楽しみです")

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)
    open_search_panel
    search_for("ライブ")

    expect(page).to have_selector(".search-result-card", wait: 10)
    js_click(".search-result-card")

    expect(page).to have_selector("#search-panel[hidden]", visible: :all, wait: 10)
    expect(page).to have_selector("#chat-message-#{target.id}.chat-message-highlight", wait: 10)
  end

  it "検索結果(スレッド返信)を選択すると、パネルが閉じてスレッドパネルが開き対象がハイライトされること" do
    root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
    reply = create(:chat_message, customer: customer, chat_room: chat_room, content: "練習の日程について返信します",
                                   reply_to_chat_message: root)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)
    open_search_panel
    search_for("練習")

    expect(page).to have_selector(".search-result-card", wait: 10)
    within ".search-result-card" do
      expect(page).to have_content("スレッド内の返信")
    end
    js_click(".search-result-card")

    expect(page).to have_selector("#search-panel[hidden]", visible: :all, wait: 10)
    expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)
    expect(page).to have_selector("[data-chat-message-id='#{reply.id}'].chat-message-highlight", wait: 10)
  end
end
