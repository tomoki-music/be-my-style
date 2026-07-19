require "rails_helper"

# 引用返信機能(通常チャット・スレッドの両方)を実ブラウザで検証する。
# 投稿ボタンにdata-confirmが付いているため、通常Composerでの投稿はaccept_confirmで包む。
# スレッドComposer(thread-reply-form)にはdata-confirmが無いため、そのままsubmitできる。
RSpec.describe "引用返信機能", type: :system do
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

  # quote-button/quote-preview-cancelはpill型・隣接flex要素があり、Capybaraのネイティブclickが
  # ずれることがあるため、chat_thread_image_size_spec.rbと同様JSで直接clickイベントを発火させる。
  def js_click(selector)
    page.evaluate_script("document.querySelector(#{selector.to_json}).click();")
  end

  describe "通常チャットでの引用返信" do
    it "引用返信ボタンでプレビューが表示され、引用解除で非表示に戻ること" do
      original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "次回のセッション曲を決めましょう")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(page).to have_selector(".quote-button", wait: 10)
      js_click(".quote-button")

      expect(page).to have_selector(".quote-preview:not([hidden])", wait: 10)
      within ".quote-preview" do
        expect(page).to have_content("さんのメッセージを引用")
        expect(page).to have_content("次回のセッション曲を決めましょう")
      end
      expect(find(".quote-to-hidden-field", visible: false).value).to eq original.id.to_s

      js_click(".quote-preview-cancel")

      expect(page).to have_selector(".quote-preview[hidden]", visible: :all, wait: 10)
      expect(find(".quote-to-hidden-field", visible: false).value).to eq ""
    end

    it "引用返信を投稿すると引用カードが表示され、クリックで引用元メッセージへスクロール・ハイライトされること" do
      original = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "次回のセッション曲を決めましょう")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      js_click(".quote-button")
      expect(page).to have_selector(".quote-preview:not([hidden])", wait: 10)

      fill_in_markdown_textarea(".form-container .markdown-textarea", "この曲がいいと思います")

      accept_confirm do
        find(".form-container .chat-form-btn").click
      end

      expect(page).to have_content("この曲がいいと思います", wait: 10)
      expect(page).to have_selector(".quote-card", wait: 10)
      expect(page).to have_content("次回のセッション曲を決めましょう")

      js_click(".quote-card")

      expect(page).to have_selector("#chat-message-#{original.id}.chat-message-highlight", wait: 10)
    end
  end

  describe "スレッド内での引用返信" do
    def open_thread_panel
      expect(page).to have_selector(".thread-replies-button", wait: 10)
      page.evaluate_script("document.querySelector('.thread-replies-button').click();")
      expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)
    end

    it "スレッドrootを引用してスレッド返信すると、スレッド内に引用カードが表示されること" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿です")
      create(:chat_message, customer: customer, chat_room: chat_room, content: "1件目の返信",
                            reply_to_chat_message: root)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      open_thread_panel

      within "#thread-panel-body" do
        expect(page).to have_selector(".quote-button", wait: 10)
      end
      page.evaluate_script("document.querySelector('#thread-panel-body .quote-button').click();")

      within "#thread-panel-body" do
        expect(page).to have_selector(".quote-preview:not([hidden])", wait: 10)
        fill_in_markdown_textarea(".thread-reply-form .markdown-textarea", "その通りですね")
        find(".thread-reply-submit").click
      end

      expect(page).to have_selector("#thread-replies-list .quote-card", wait: 10)
      within "#thread-replies-list" do
        expect(page).to have_content("元の投稿です")
      end
    end

    it "スレッドを閉じて再度開くと、引用プレビューの状態が残っていないこと" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿です")
      create(:chat_message, customer: customer, chat_room: chat_room, content: "1件目の返信",
                            reply_to_chat_message: root)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      open_thread_panel

      expect(page).to have_selector("#thread-panel-body .quote-button", wait: 10)
      page.evaluate_script("document.querySelector('#thread-panel-body .quote-button').click();")
      expect(page).to have_selector("#thread-panel-body .quote-preview:not([hidden])", wait: 10)

      page.evaluate_script("document.querySelector('.thread-panel-close').click();")
      expect(page).to have_selector("#thread-panel[hidden]", visible: :all, wait: 10)

      open_thread_panel
      expect(page).to have_selector("#thread-panel-body .quote-preview[hidden]", visible: :all, wait: 10)
    end
  end

  # Markdown Composerのtextareaはbfcache対策等でスクリプトから値を参照されるため、
  # 単純なfill_inではなくJSで直接valueを設定しinputイベントを発火させる
  # (textareaは複数存在しうるため、CSSセレクタで対象を一意に絞り込む)。
  def fill_in_markdown_textarea(selector, content)
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector(#{selector.to_json});
        el.value = #{content.to_json};
        el.dispatchEvent(new Event('input'));
      })();
    JS
  end
end
