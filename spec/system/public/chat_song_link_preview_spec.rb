require "rails_helper"

# 曲リンクカード(Phase5-A)の表示を実ブラウザで検証する。
# 曲解決はChat::LinkPreviewSyncService内で同期的に行われる(Job非経由)ため、
# chat_event_link_preview_spec.rbと同様、既にstatus: fetchedなChatMessageLinkPreviewを
# 直接作成し、「サーバーが返したHTMLがそのまま表示されること」だけを確認する。
RSpec.describe "曲リンクカード", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:community) { create(:community) }
  let(:event_owner) { create(:customer) }

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

  def fill_in_markdown_textarea(selector, content)
    page.evaluate_script(<<~JS)
      (function () {
        var el = document.querySelector(#{selector.to_json});
        el.value = #{content.to_json};
        el.dispatchEvent(new Event('input'));
      })();
    JS
  end

  def submit_chat_form
    page.execute_script("window.confirm = function() { return true; };")
    page.execute_script("document.querySelector('.form-container .chat-form-btn').click();")
  end

  def create_event(**attrs)
    create(:event, :event_with_songs, customer: event_owner, community: community, **attrs)
  end

  def song_url_for(song)
    "https://www.example.com/public/events/#{song.event_id}/songs/#{song.id}"
  end

  def create_link_preview(chat_message, song, **attrs)
    create(:chat_message_link_preview, :song, chat_message: chat_message,
                                               url: song_url_for(song),
                                               external_id: song.id.to_s,
                                               title: song.song_name,
                                               author_name: song.artist_name,
                                               **attrs)
  end

  it "曲名・アーティスト名・関連イベント名・詳細リンクが表示されること" do
    event = create_event(event_name: "セッション会")
    song = create(:song, event: event, song_name: "マリーゴールド", artist_name: "あいみょん")
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                                content: "見て #{song_url_for(song)}")
    create_link_preview(target, song)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".link-preview-card--song", wait: 10)
      expect(page).to have_content("マリーゴールド")
      expect(page).to have_content("あいみょん")
      expect(page).to have_content("セッション会")
      expect(page).to have_link("曲の詳細を見る ↗", href: public_event_song_path(event, song))
    end
  end

  it "アーティスト名が未登録でもレイアウトが崩れず表示されること" do
    event = create_event
    song = create(:song, event: event, song_name: "アーティスト未設定曲", artist_name: nil)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
    create_link_preview(target, song)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".link-preview-card--song", wait: 10)
      expect(page).to have_content("アーティスト未設定曲")
    end
  end

  it "参加者が0人のパートがある場合、募集中パート名が表示されること" do
    event = create_event
    song = create(:song, event: event, song_name: "募集中の曲")
    create(:join_part, song: song, join_part_name: "ギター")
    filled_part = create(:join_part, song: song, join_part_name: "ベース")
    create(:join_part_customer, join_part: filled_part, customer: event_owner)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
    create_link_preview(target, song)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_content("募集中：ギター", wait: 10)
      expect(page).not_to have_content("ベース")
    end
  end

  it "全パートに参加者がいる場合、募集中欄が表示されないこと" do
    event = create_event
    song = create(:song, event: event, song_name: "成立済みの曲")
    part = create(:join_part, song: song, join_part_name: "ボーカル")
    create(:join_part_customer, join_part: part, customer: event_owner)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
    create_link_preview(target, song)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".link-preview-card--song", wait: 10)
      expect(page).not_to have_selector(".link-preview-card-song-recruiting")
    end
  end

  it "長い曲名・アーティスト名でもカード幅が広がらないこと" do
    event = create_event
    song = create(:song, event: event, song_name: "い" * 60, artist_name: "あ" * 30)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
    create_link_preview(target, song)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      card_width = page.evaluate_script("document.querySelector('.link-preview-card--song').getBoundingClientRect().width")
      expect(card_width).to be <= 320
    end
  end

  it "曲削除後はスナップショットによるフォールバックカードが表示され、詳細リンクが表示されないこと" do
    event = create_event
    song = create(:song, event: event, song_name: "削除予定の曲")
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
    create_link_preview(target, song)
    deleted_song_path = public_event_song_path(event, song)
    song.destroy!

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_content("この曲は削除されました", wait: 10)
      expect(page).to have_content("削除予定の曲")
      expect(page).not_to have_link(href: deleted_song_path)
    end
  end

  it "モバイル幅(375px)でもカードが横スクロールを発生させず表示されること" do
    event = create_event
    song = create(:song, event: event, song_name: "モバイル確認曲")
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
    create_link_preview(target, song)

    page.driver.browser.manage.window.resize_to(375, 812)
    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".link-preview-card--song", wait: 10)
    end
    body_scroll_width = page.evaluate_script("document.body.scrollWidth")
    viewport_width = page.evaluate_script("window.innerWidth")
    expect(body_scroll_width).to be <= viewport_width
  end

  it "スレッドパネル内の返信でも曲カードが表示されること" do
    root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元メッセージ")
    event = create_event
    song = create(:song, event: event, song_name: "スレッド内の曲")
    reply = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                              content: song_url_for(song), reply_to_chat_message: root)
    create_link_preview(reply, song)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    expect(page).to have_selector(".thread-replies-button", wait: 10)
    page.evaluate_script("document.querySelector('.thread-replies-button').click();")
    expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)

    within "#thread-panel-body" do
      expect(page).to have_selector(".link-preview-card--song", wait: 10)
      expect(page).to have_content("スレッド内の曲")
    end
  end

  it "曲URLを新規投稿すると、リロードなしで送信直後に曲カードが表示されること" do
    create(:chat_message, customer: other_customer, chat_room: chat_room, content: "こんにちは")
    event = create_event
    song = create(:song, event: event, song_name: "送信直後表示確認曲")

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)
    expect(page).to have_selector(".form-container .chat-form-btn", wait: 10)

    fill_in_markdown_textarea(".form-container .markdown-textarea", "見て #{song_url_for(song)}")
    submit_chat_form

    expect(page).to have_selector(".link-preview-card--song", wait: 10)
    expect(page).to have_content("送信直後表示確認曲")
  end
end
