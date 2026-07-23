require "rails_helper"

# URLリンクカード(Phase4-A)の表示を実ブラウザで検証する。ActionCable/Polling等を
# 導入しない設計(案B)のため、JS操作は不要で「サーバーが返したHTMLがそのまま
# 表示されること」だけを確認すれば十分(既存のpin/searchのようなjs_clickは不要)。
RSpec.describe "URLリンクカード", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:video_url) { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }

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

  # chat_quote_reply_spec.rbと同じ理由(bfcache対策等)でfill_inではなくJSで直接値を設定する。
  def fill_in_markdown_textarea(selector, content)
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector(#{selector.to_json});
        el.value = #{content.to_json};
        el.dispatchEvent(new Event('input'));
      })();
    JS
  end

  it "取得済みのリンクカードがタイトル・チャンネル名・サムネイル付きで表示されること" do
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: "見て #{video_url}")
    create(:chat_message_link_preview, chat_message: target, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                        url: video_url, position: 0, status: :fetched, fetched_at: Time.current,
                                        title: "テスト動画タイトル", author_name: "テストチャンネル",
                                        thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".link-preview-card", wait: 10)
      expect(page).to have_content("テスト動画タイトル")
      expect(page).to have_content("テストチャンネル")
      expect(page).to have_link(href: video_url)
    end
  end

  it "取得前(pending)のプレビューはカードとして表示されず、本文中のリンクのみ表示されること" do
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: "見て #{video_url}")
    create(:chat_message_link_preview, chat_message: target, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                        url: video_url, position: 0, status: :pending)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).not_to have_selector(".link-preview-card")
      expect(page).to have_link(href: video_url)
    end
  end

  it "取得失敗(failed)のプレビューもカードとして表示されず、本文中のリンクのみ表示されること" do
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: "見て #{video_url}")
    create(:chat_message_link_preview, chat_message: target, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                        url: video_url, position: 0, status: :failed, failure_reason: "404")

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).not_to have_selector(".link-preview-card")
      expect(page).to have_link(href: video_url)
    end
  end

  it "URLを含むメッセージを投稿した直後は、まだカードが表示されずプレーンリンクのまま表示されること(案B: pollingを行わない設計)" do
    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    fill_in_markdown_textarea(".form-container .markdown-textarea", "見て #{video_url}")
    accept_confirm do
      find(".form-container .chat-form-btn").click
    end

    expect(page).to have_content("メッセージを送信しました", wait: 10)
    chat_message = ChatMessage.order(:created_at).last
    expect(chat_message.chat_message_link_previews.first).to be_pending

    within "#chat-message-#{chat_message.id}" do
      expect(page).not_to have_selector(".link-preview-card")
      expect(page).to have_link(href: video_url)
    end
  end
end
