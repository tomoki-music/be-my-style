require "rails_helper"

# ピン留め機能を実ブラウザで検証する。既存のchat_message_search_spec.rbと同じ方針
# (selenium_chrome_headless、フォームログイン、動的パネル要素はjs_clickで操作)で、
# ピンボタンの表示・ピン留め・ピン一覧パネル・ジャンプ・解除を確認する。
RSpec.describe "ピン留め機能", type: :system do
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

  def open_pin_panel
    expect(page).to have_selector(".chat-pin-trigger", wait: 10)
    js_click(".chat-pin-trigger")
    expect(page).to have_selector("#pin-panel:not([hidden])", wait: 10)
  end

  it "他人の投稿にピン留めボタンが表示され、押すとピン済みバッジに変わること" do
    target = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "重要なお知らせです")

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".pin-button--pin", wait: 10)
    end
    js_click("#chat-message-#{target.id} .pin-button--pin")

    within "#chat-message-#{target.id}" do
      expect(page).to have_content("ピン留め済み", wait: 10)
      expect(page).to have_selector(".pin-button--unpin", wait: 10)
    end
  end

  it "ピン留め一覧パネルを開くと、ピン留めしたメッセージが表示されること" do
    target = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "重要なお知らせです")

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    js_click("#chat-message-#{target.id} .pin-button--pin")
    expect(page).to have_content("ピン留め済み", wait: 10)

    open_pin_panel

    within "#pin-panel-body" do
      expect(page).to have_content("重要なお知らせです", wait: 10)
    end
  end

  it "ピン留め一覧から通常メッセージを選択すると、パネルが閉じて対象がハイライトされること" do
    target = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "重要なお知らせです")
    create(:chat_message_pin, chat_message: target, pinned_by_customer: customer)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)
    open_pin_panel

    expect(page).to have_selector(".pin-result-jump", wait: 10)
    js_click(".pin-result-jump")

    expect(page).to have_selector("#pin-panel[hidden]", visible: :all, wait: 10)
    expect(page).to have_selector("#chat-message-#{target.id}.chat-message-highlight", wait: 10)
  end

  it "ピン留め一覧からスレッド返信を選択すると、パネルが閉じてスレッドパネルが開き対象がハイライトされること" do
    root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿")
    reply = create(:chat_message, customer: customer, chat_room: chat_room, content: "重要な返信です",
                                   reply_to_chat_message: root)
    create(:chat_message_pin, chat_message: reply, pinned_by_customer: customer)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)
    open_pin_panel

    expect(page).to have_selector(".pin-result-jump", wait: 10)
    within ".pin-result-card" do
      expect(page).to have_content("スレッド内の返信")
    end
    js_click(".pin-result-jump")

    expect(page).to have_selector("#pin-panel[hidden]", visible: :all, wait: 10)
    expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)
    expect(page).to have_selector("[data-chat-message-id='#{reply.id}'].chat-message-highlight", wait: 10)
  end

  it "ピン留め一覧から解除すると、一覧・本文の両方から反映されること" do
    target = create(:chat_message, customer: customer, chat_room: chat_room, content: "重要なお知らせです")
    create(:chat_message_pin, chat_message: target, pinned_by_customer: customer)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)
    open_pin_panel

    expect(page).to have_selector(".pin-result-unpin", wait: 10)
    js_click(".pin-result-unpin")

    within "#pin-panel-body" do
      expect(page).to have_content("ピン留めされたメッセージはまだありません", wait: 10)
    end

    js_click(".pin-panel-close")
    expect(page).to have_selector("#pin-panel[hidden]", visible: :all, wait: 10)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".pin-button--pin", wait: 10)
      expect(page).not_to have_content("ピン留め済み")
    end
  end
end
