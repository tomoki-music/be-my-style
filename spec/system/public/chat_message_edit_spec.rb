require "rails_helper"

# メッセージ編集機能(インライン編集UI)を実ブラウザで検証する。
# 既存のchat_quote_reply_spec.rb(system)と同じ認証・操作パターンを踏襲する。
RSpec.describe "メッセージ編集機能", type: :system do
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

  # edit-button/edit-cancel-button/edit-save-buttonはquote-button等と同様pill型・
  # 隣接flex要素があり、Capybaraのネイティブclickがずれることがあるため、
  # chat_quote_reply_spec.rbと同様JSで直接clickイベントを発火させる。
  def js_click(selector)
    page.evaluate_script("document.querySelector(#{selector.to_json}).click();")
  end

  # Markdown Composerのtextareaはbfcache対策等でスクリプトから値を参照されるため、
  # 単純なfill_inではなくJSで直接valueを設定しinputイベントを発火させる。
  def fill_in_markdown_textarea(selector, content)
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector(#{selector.to_json});
        el.value = #{content.to_json};
        el.dispatchEvent(new Event('input'));
      })();
    JS
  end

  describe "通常タイムラインでの編集" do
    it "投稿者本人のメッセージにのみ編集ボタンが表示されること" do
      own_message = create(:chat_message, customer: customer, chat_room: chat_room, content: "自分の投稿")
      other_message = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "相手の投稿")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(page).to have_selector("#chat-message-#{own_message.id} .edit-button", wait: 10)
      within "#chat-message-#{other_message.id}" do
        expect(page).not_to have_selector(".edit-button")
      end
    end

    it "添付のみ・スタンプのみのメッセージには編集ボタンが表示されないこと" do
      image_only = build(:chat_message, customer: customer, chat_room: chat_room, content: nil)
      image_only.attachments.attach(
        io: File.open(Rails.root.join("spec/fixtures/thread_sample_image.png")),
        filename: "test.png",
        content_type: "image/png"
      )
      image_only.save!
      stamp_only = create(:chat_message, customer: customer, chat_room: chat_room, content: nil, stamp_type: "fire")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(page).to have_selector("#chat-message-#{image_only.id}", wait: 10)
      within "#chat-message-#{image_only.id}" do
        expect(page).not_to have_selector(".edit-button")
      end
      within "#chat-message-#{stamp_only.id}" do
        expect(page).not_to have_selector(".edit-button")
      end
    end

    it "編集ボタンを押すと本文がtextareaに置き換わり、既存の本文が入っていること" do
      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前の本文")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      js_click("#chat-message-#{own_message.id} .edit-button")

      within "#chat-message-#{own_message.id}" do
        expect(page).to have_selector(".message-edit-form:not([hidden])", wait: 10)
        expect(find(".message-edit-form .markdown-textarea", visible: false).value).to eq "編集前の本文"
      end
    end

    it "保存すると本文が更新され、「編集済み」ラベルが表示されること" do
      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前の本文")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      js_click("#chat-message-#{own_message.id} .edit-button")
      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form:not([hidden])", wait: 10)

      fill_in_markdown_textarea("#chat-message-#{own_message.id} .markdown-textarea", "編集後の本文です")
      js_click("#chat-message-#{own_message.id} .edit-save-button")

      expect(page).to have_content("編集後の本文です", wait: 10)
      expect(page).to have_selector(".edited-label", wait: 10)
      expect(own_message.reload.content).to eq "編集後の本文です"
      expect(own_message.edited_at).to be_present
    end

    it "キャンセルすると本文表示に戻り、DBの内容が変わらないこと" do
      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前の本文")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      js_click("#chat-message-#{own_message.id} .edit-button")
      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form:not([hidden])", wait: 10)

      fill_in_markdown_textarea("#chat-message-#{own_message.id} .markdown-textarea", "保存されないはずの本文")
      js_click("#chat-message-#{own_message.id} .edit-cancel-button")

      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form[hidden]", visible: :all, wait: 10)
      expect(page).to have_content("編集前の本文", wait: 10)
      expect(own_message.reload.content).to eq "編集前の本文"
      expect(own_message.edited_at).to be_nil
    end

    it "空本文で保存しようとするとエラーメッセージが表示され、本文が変わらないこと" do
      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前の本文")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      js_click("#chat-message-#{own_message.id} .edit-button")
      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form:not([hidden])", wait: 10)

      fill_in_markdown_textarea("#chat-message-#{own_message.id} .markdown-textarea", "")
      js_click("#chat-message-#{own_message.id} .edit-save-button")

      within "#chat-message-#{own_message.id}" do
        expect(page).to have_selector(".edit-errors:not([hidden])", wait: 10)
      end
      expect(own_message.reload.content).to eq "編集前の本文"
    end

    it "メンション付きメッセージの編集開始時は内部記法ではなく@usernameが表示され、変更せず保存してもメンションが維持されること" do
      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room,
                            content: "[@#{other_customer.name}](customer:#{other_customer.id}) こんにちは")
      Chat::MentionSyncService.call(own_message)
      expect(own_message.chat_mentions.count).to eq 1

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      js_click("#chat-message-#{own_message.id} .edit-button")
      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form:not([hidden])", wait: 10)

      textarea_value = find("#chat-message-#{own_message.id} .markdown-textarea", visible: false).value
      expect(textarea_value).to eq "@#{other_customer.name} こんにちは"
      expect(textarea_value).not_to include("customer:")

      js_click("#chat-message-#{own_message.id} .edit-save-button")

      expect(page).to have_selector("#chat-message-#{own_message.id} .edited-label", wait: 10)
      within "#chat-message-#{own_message.id}" do
        expect(page).to have_selector(".chat-mention", wait: 10)
      end
      expect(own_message.reload.content).to eq "[@#{other_customer.name}](customer:#{other_customer.id}) こんにちは"
      expect(own_message.chat_mentions.reload.count).to eq 1
    end
  end

  describe "スレッドパネル内での編集" do
    def open_thread_panel
      expect(page).to have_selector(".thread-replies-button", wait: 10)
      page.evaluate_script("document.querySelector('.thread-replies-button').click();")
      expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)
    end

    it "スレッド内の自分の返信メッセージを編集でき、パネル内表示が更新されること" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿です")
      reply = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "編集前の返信",
                                     reply_to_chat_message: root)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      open_thread_panel

      within "#thread-panel-body" do
        expect(page).to have_selector("[data-chat-message-id='#{reply.id}'] .edit-button", wait: 10)
      end
      page.evaluate_script("document.querySelector('#thread-panel-body [data-chat-message-id=\"#{reply.id}\"] .edit-button').click();")

      within "#thread-panel-body" do
        expect(page).to have_selector(".message-edit-form:not([hidden])", wait: 10)
      end

      fill_in_markdown_textarea("#thread-panel-body [data-chat-message-id='#{reply.id}'] .markdown-textarea", "編集後の返信です")
      page.evaluate_script("document.querySelector('#thread-panel-body [data-chat-message-id=\"#{reply.id}\"] .edit-save-button').click();")

      within "#thread-panel-body" do
        expect(page).to have_content("編集後の返信です", wait: 10)
      end
      expect(reply.reload.content).to eq "編集後の返信です"
    end

    it "スタンプのみの返信メッセージには、スレッドパネル内でも編集ボタンが表示されないこと" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元の投稿です")
      stamp_reply = create(:chat_message, customer: customer, chat_room: chat_room, content: nil, stamp_type: "fire",
                                           reply_to_chat_message: root)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      open_thread_panel

      within "#thread-panel-body" do
        expect(page).to have_selector("[data-chat-message-id='#{stamp_reply.id}']", wait: 10)
        within "[data-chat-message-id='#{stamp_reply.id}']" do
          expect(page).not_to have_selector(".edit-button")
        end
      end
    end
  end
end
