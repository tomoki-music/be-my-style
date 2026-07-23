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

  describe "UI表示バリエーション" do
    it "複数URL(最大3件)がposition順にすべてカード表示されること" do
      urls = %w[aaaaaaaaaaa bbbbbbbbbbb ccccccccccc]
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                                  content: urls.map { |id| "https://youtu.be/#{id}" }.join(" "))
      urls.each_with_index do |id, index|
        create(:chat_message_link_preview, chat_message: target, provider: :youtube, external_id: id,
                                            url: "https://www.youtube.com/watch?v=#{id}", position: index,
                                            status: :fetched, fetched_at: Time.current, title: "動画#{index}")
      end

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card", count: 3, wait: 10)
        cards = all(".link-preview-card")
        expect(cards.map { |card| card.find(".link-preview-card-title").text }).to eq %w[動画0 動画1 動画2]
      end
    end

    it "YouTube以外の通常URLは従来どおりプレーンリンクのまま表示され、カードにならないこと" do
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                                  content: "参考: https://example.com/article")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).not_to have_selector(".link-preview-card")
        expect(page).to have_link(href: "https://example.com/article")
      end
    end

    it "Markdownリンク記法のURLも検出されカード表示されること" do
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                                  content: "[この曲どうですか](#{video_url})")
      create(:chat_message_link_preview, chat_message: target, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                          url: video_url, position: 0, status: :fetched, fetched_at: Time.current,
                                          title: "テスト動画タイトル")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_content("この曲どうですか")
        expect(page).to have_selector(".link-preview-card", wait: 10)
      end
    end

    it "長いタイトル・長いチャンネル名でもレイアウトが崩れず、省略スタイルのクラスが適用されること" do
      long_title = "とても長い動画タイトル" * 10
      long_author = "とても長いチャンネル名" * 10
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: video_url)
      create(:chat_message_link_preview, chat_message: target, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                          url: video_url, position: 0, status: :fetched, fetched_at: Time.current,
                                          title: long_title, author_name: long_author)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-title", text: long_title, wait: 10)
        expect(page).to have_selector(".link-preview-card-author", text: long_author)
        card_width = page.evaluate_script("document.querySelector('.link-preview-card').getBoundingClientRect().width")
        expect(card_width).to be <= 340
      end
    end

    it "画像添付とYouTube URLが同一メッセージに共存できること" do
      target = build(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: "見て #{video_url}")
      target.attachments.attach(
        io: File.open(Rails.root.join("spec/fixtures/thread_sample_image.png")),
        filename: "test.png",
        content_type: "image/png"
      )
      target.save!
      create(:chat_message_link_preview, chat_message: target, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                          url: video_url, position: 0, status: :fetched, fetched_at: Time.current,
                                          title: "テスト動画タイトル")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card", wait: 10)
        expect(page).to have_selector(".message-image")
      end
    end

    it "スタンプのみのメッセージにはカードもURLも表示されないこと" do
      target = create(:chat_message, customer: other_customer, chat_room: chat_room, content: nil, stamp_type: "fire")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".stamp-badge", wait: 10)
        expect(page).not_to have_selector(".link-preview-card")
      end
    end

    it "モバイル幅(375px)でもカードが横スクロールを発生させず表示されること" do
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: video_url)
      create(:chat_message_link_preview, chat_message: target, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                          url: video_url, position: 0, status: :fetched, fetched_at: Time.current,
                                          title: "テスト動画タイトル")

      page.driver.browser.manage.window.resize_to(375, 812)
      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card", wait: 10)
      end
      body_scroll_width = page.evaluate_script("document.body.scrollWidth")
      viewport_width = page.evaluate_script("window.innerWidth")
      expect(body_scroll_width).to be <= viewport_width
    end

    it "スレッドパネル内の返信でもカードが表示されること" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元メッセージ")
      reply = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                                content: "見て #{video_url}", reply_to_chat_message: root)
      create(:chat_message_link_preview, chat_message: reply, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                          url: video_url, position: 0, status: :fetched, fetched_at: Time.current,
                                          title: "テスト動画タイトル")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(page).to have_selector(".thread-replies-button", wait: 10)
      page.evaluate_script("document.querySelector('.thread-replies-button').click();")
      expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)

      within "#thread-panel-body" do
        expect(page).to have_selector(".link-preview-card", wait: 10)
        expect(page).to have_content("テスト動画タイトル")
      end
    end
  end

  describe "編集機能" do
    def js_click(selector)
      page.evaluate_script("document.querySelector(#{selector.to_json}).click();")
    end

    it "編集でURLを追加すると、直後はpendingのままカードが表示されないこと" do
      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "本文だけ")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      js_click("#chat-message-#{own_message.id} .edit-button")
      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form:not([hidden])", wait: 10)

      fill_in_markdown_textarea("#chat-message-#{own_message.id} .markdown-textarea", "見て #{video_url}")
      js_click("#chat-message-#{own_message.id} .edit-save-button")

      expect(page).to have_selector("#chat-message-#{own_message.id} .edited-label", wait: 10)
      expect(own_message.reload.chat_message_link_previews.count).to eq 1
      expect(own_message.chat_message_link_previews.first).to be_pending
      within "#chat-message-#{own_message.id}" do
        expect(page).not_to have_selector(".link-preview-card")
      end
    end

    it "編集でURLを削除すると、表示済みだったカードが直後に消えること" do
      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "見て #{video_url}")
      create(:chat_message_link_preview, chat_message: own_message, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                          url: video_url, position: 0, status: :fetched, fetched_at: Time.current,
                                          title: "テスト動画タイトル")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      expect(page).to have_selector("#chat-message-#{own_message.id} .link-preview-card", wait: 10)

      js_click("#chat-message-#{own_message.id} .edit-button")
      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form:not([hidden])", wait: 10)
      fill_in_markdown_textarea("#chat-message-#{own_message.id} .markdown-textarea", "URLを削除しました")
      js_click("#chat-message-#{own_message.id} .edit-save-button")

      expect(page).to have_content("URLを削除しました", wait: 10)
      within "#chat-message-#{own_message.id}" do
        expect(page).not_to have_selector(".link-preview-card")
      end
      expect(own_message.reload.chat_message_link_previews.count).to eq 0
    end

    it "編集でURLを別動画に変更すると、旧プレビューが削除され新プレビューがpendingで作られること" do
      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "見て #{video_url}")
      create(:chat_message_link_preview, chat_message: own_message, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                          url: video_url, position: 0, status: :fetched, fetched_at: Time.current,
                                          title: "旧動画タイトル")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      expect(page).to have_selector("#chat-message-#{own_message.id} .link-preview-card", wait: 10)

      new_url = "https://youtu.be/bbbbbbbbbbb"
      js_click("#chat-message-#{own_message.id} .edit-button")
      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form:not([hidden])", wait: 10)
      fill_in_markdown_textarea("#chat-message-#{own_message.id} .markdown-textarea", "見て #{new_url}")
      js_click("#chat-message-#{own_message.id} .edit-save-button")

      expect(page).to have_selector("#chat-message-#{own_message.id} .edited-label", wait: 10)
      within "#chat-message-#{own_message.id}" do
        expect(page).not_to have_selector(".link-preview-card")
      end
      previews = own_message.reload.chat_message_link_previews
      expect(previews.count).to eq 1
      expect(previews.first.external_id).to eq "bbbbbbbbbbb"
      expect(previews.first).to be_pending
    end

    it "本文編集でURLが変わらない場合、既存プレビュー(id・取得済みデータ)がそのまま維持されること" do
      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "見て #{video_url}")
      preview = create(:chat_message_link_preview, chat_message: own_message, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                                     url: video_url, position: 0, status: :fetched, fetched_at: Time.current,
                                                     title: "変わらないタイトル")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      expect(page).to have_selector("#chat-message-#{own_message.id} .link-preview-card", wait: 10)

      js_click("#chat-message-#{own_message.id} .edit-button")
      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form:not([hidden])", wait: 10)
      fill_in_markdown_textarea("#chat-message-#{own_message.id} .markdown-textarea", "見てね #{video_url} 良い曲です")
      js_click("#chat-message-#{own_message.id} .edit-save-button")

      expect(page).to have_selector("#chat-message-#{own_message.id} .edited-label", wait: 10)
      within "#chat-message-#{own_message.id}" do
        expect(page).to have_selector(".link-preview-card", wait: 10)
        expect(page).to have_content("変わらないタイトル")
      end
      reloaded = own_message.reload.chat_message_link_previews.first
      expect(reloaded.id).to eq preview.id
      expect(reloaded.title).to eq "変わらないタイトル"
    end

    it "同一動画が30日以内に取得済みの場合、編集で追加した直後からキャッシュ再利用でカードが表示されること" do
      cached_message = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: video_url)
      create(:chat_message_link_preview, chat_message: cached_message, provider: :youtube, external_id: "dQw4w9WgXcQ",
                                          url: video_url, position: 0, status: :fetched, fetched_at: 1.day.ago,
                                          title: "キャッシュ済みタイトル")

      own_message = create(:chat_message, :markdown, customer: customer, chat_room: chat_room, content: "本文だけ")

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      js_click("#chat-message-#{own_message.id} .edit-button")
      expect(page).to have_selector("#chat-message-#{own_message.id} .message-edit-form:not([hidden])", wait: 10)
      fill_in_markdown_textarea("#chat-message-#{own_message.id} .markdown-textarea", "見て #{video_url}")
      js_click("#chat-message-#{own_message.id} .edit-save-button")

      expect(page).to have_selector("#chat-message-#{own_message.id} .edited-label", wait: 10)
      within "#chat-message-#{own_message.id}" do
        expect(page).to have_selector(".link-preview-card", wait: 10)
        expect(page).to have_content("キャッシュ済みタイトル")
      end
      expect(own_message.reload.chat_message_link_previews.first).to be_fetched
    end
  end
end
