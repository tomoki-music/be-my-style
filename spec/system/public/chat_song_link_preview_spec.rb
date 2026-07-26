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

  it "参加者が0人のパートがある場合、募集中パート名がバッジで表示されること" do
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
      expect(page).to have_content("メンバー募集中", wait: 10)
      expect(page).to have_selector(".link-preview-card-song-recruitment-badge", text: "ギター")
      expect(page).not_to have_selector(".link-preview-card-song-recruitment-badge", text: "ベース")
      expect(page).not_to have_content("ベース")
    end
  end

  it "募集中パートが複数ある場合、それぞれが個別バッジとして表示されること" do
    event = create_event
    song = create(:song, event: event, song_name: "複数募集中の曲")
    create(:join_part, song: song, join_part_name: "ギター")
    create(:join_part, song: song, join_part_name: "キーボード")
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
    create_link_preview(target, song)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_content("メンバー募集中", wait: 10)
      badges = page.all(".link-preview-card-song-recruitment-badge")
      expect(badges.map(&:text)).to contain_exactly("ギター", "キーボード")
      expect(page).to have_link("曲の詳細を見る ↗", href: public_event_song_path(event, song))
    end
  end

  it "全パートに参加者がいる場合、募集中パートがない案内を表示すること" do
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
      expect(page).to have_content("現在、募集中のパートはありません")
      expect(page).not_to have_content("メンバー募集中")
      expect(page).not_to have_selector(".link-preview-card-song-recruitment-badge")
    end
  end

  it "長いパート名でもカードが崩れず、バッジ内で折り返されること" do
    event = create_event
    song = create(:song, event: event, song_name: "長いパート名の曲")
    create(:join_part, song: song, join_part_name: "ギ" * 40)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
    create_link_preview(target, song)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".link-preview-card-song-recruitment-badge", wait: 10)
      card_width = page.evaluate_script("document.querySelector('.link-preview-card--song').getBoundingClientRect().width")
      expect(card_width).to be <= 320
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

  describe "コード譜情報(Phase5-C)" do
    it "Key・Capo・コード譜リンクが表示され、募集バッジより上に配置されること" do
      event = create_event
      song = create(:song, :with_chord_sheet, event: event, song_name: "コード譜付きの曲")
      create(:join_part, song: song, join_part_name: "ギター")
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-chord-sheet", wait: 10)
        expect(page).to have_content("Key：")
        expect(page).to have_content("G")
        expect(page).to have_content("Capo：")
        expect(page).to have_link("コード譜を見る ↗", href: song.chord_sheet_url)
        expect(page).not_to have_content("初心者向けの簡単コード版です")

        chord_sheet_top = page.evaluate_script("document.querySelector('.link-preview-card-chord-sheet').getBoundingClientRect().top")
        recruitment_top = page.evaluate_script("document.querySelector('.link-preview-card-song-recruitment').getBoundingClientRect().top")
        expect(chord_sheet_top).to be < recruitment_top
      end
    end

    it "Capo 0の場合「なし」と表示されること" do
      event = create_event
      song = create(:song, event: event, song_name: "カポなしの曲", capo: 0)
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-chord-sheet-capo", wait: 10)
        expect(page.find(".link-preview-card-chord-sheet-capo").text).to include("なし")
      end
    end

    it "Capoが未入力の場合、Capo表示がないこと" do
      event = create_event
      song = create(:song, event: event, song_name: "Capo未入力の曲", capo: nil, musical_key: "G")
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-chord-sheet", wait: 10)
        expect(page).not_to have_selector(".link-preview-card-chord-sheet-capo")
      end
    end

    it "Keyがない場合、Key表示がないこと" do
      event = create_event
      song = create(:song, event: event, song_name: "Keyなしの曲", musical_key: nil, capo: 2)
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-chord-sheet", wait: 10)
        expect(page).not_to have_selector(".link-preview-card-chord-sheet-key")
      end
    end

    it "コード譜URLがない場合、コード譜リンクが表示されないこと" do
      event = create_event
      song = create(:song, event: event, song_name: "URLなしの曲", musical_key: "G", chord_sheet_url: nil)
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-chord-sheet", wait: 10)
        expect(page).not_to have_selector(".link-preview-card-chord-sheet-link")
      end
    end

    it "コード譜情報が全て未入力の場合、コード譜ブロック自体が表示されないこと" do
      event = create_event
      song = create(:song, event: event, song_name: "コード譜情報なしの曲",
                            musical_key: nil, capo: nil, chord_sheet_url: nil, chord_sheet_note: nil)
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card--song", wait: 10)
        expect(page).not_to have_selector(".link-preview-card-chord-sheet")
      end
    end

    it "HTML上でリンクの入れ子が発生していないこと" do
      event = create_event
      song = create(:song, :with_chord_sheet, event: event, song_name: "リンク入れ子確認の曲")
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-chord-sheet-link", wait: 10)
      end

      nested_anchor_count = page.evaluate_script(
        "document.querySelectorAll('#chat-message-#{target.id} .link-preview-card--song a a').length"
      )
      expect(nested_anchor_count).to eq 0
    end

    it "コード譜リンクとSong詳細リンクをそれぞれ正しく認識できること" do
      event = create_event
      song = create(:song, :with_chord_sheet, event: event, song_name: "2つのリンクを持つ曲")
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_link("コード譜を見る ↗", href: song.chord_sheet_url, wait: 10)
        expect(page).to have_link("曲の詳細を見る ↗", href: public_event_song_path(event, song))
      end
    end

    it "外部リンクにtarget=\"_blank\"とrel=\"noopener noreferrer\"が付くこと" do
      event = create_event
      song = create(:song, :with_chord_sheet, event: event, song_name: "外部リンク属性確認の曲")
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-chord-sheet-link", wait: 10)
        link = find(".link-preview-card-chord-sheet-link")
        expect(link[:target]).to eq "_blank"
        expect(link[:rel]).to eq "noopener noreferrer"
      end
    end

    it "Event編集でSongのコード譜情報を変えると、既存カードへリロード後にライブ反映されること" do
      event = create_event
      song = create(:song, event: event, song_name: "ライブ反映確認の曲")
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card--song", wait: 10)
        expect(page).not_to have_selector(".link-preview-card-chord-sheet")
      end

      song.update!(musical_key: "D", capo: 5, chord_sheet_url: "https://example.com/updated-chord-sheet")
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-chord-sheet", wait: 10)
        expect(page).to have_content("D")
        expect(page).to have_link("コード譜を見る ↗", href: "https://example.com/updated-chord-sheet")
      end
    end

    it "コード譜URLを空にすると、既存カードからリンクが消えること" do
      event = create_event
      song = create(:song, :with_chord_sheet, event: event, song_name: "URL削除確認の曲")
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)
      within "#chat-message-#{target.id}" do
        expect(page).to have_link("コード譜を見る ↗", wait: 10)
      end

      song.update!(chord_sheet_url: nil)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card--song", wait: 10)
        expect(page).not_to have_link("コード譜を見る ↗")
      end
    end

    it "スレッドパネル内でもコード譜情報が表示されること" do
      root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元メッセージ")
      event = create_event
      song = create(:song, :with_chord_sheet, event: event, song_name: "スレッド内コード譜曲")
      reply = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                                content: song_url_for(song), reply_to_chat_message: root)
      create_link_preview(reply, song)

      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      expect(page).to have_selector(".thread-replies-button", wait: 10)
      page.evaluate_script("document.querySelector('.thread-replies-button').click();")
      expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)

      within "#thread-panel-body" do
        expect(page).to have_selector(".link-preview-card-chord-sheet", wait: 10)
        expect(page).to have_link("コード譜を見る ↗", href: song.chord_sheet_url)
      end
    end

    it "モバイル幅(375px)でもコード譜情報を含むカードが横スクロールを発生させないこと" do
      event = create_event
      song = create(:song, :with_chord_sheet, event: event, song_name: "モバイルコード譜確認曲")
      target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: song_url_for(song))
      create_link_preview(target, song)

      page.driver.browser.manage.window.resize_to(375, 812)
      sign_in_via_form(customer)
      visit public_chat_room_path(chat_room, customer_id: other_customer.id)

      within "#chat-message-#{target.id}" do
        expect(page).to have_selector(".link-preview-card-chord-sheet", wait: 10)
      end
      body_scroll_width = page.evaluate_script("document.body.scrollWidth")
      viewport_width = page.evaluate_script("window.innerWidth")
      expect(body_scroll_width).to be <= viewport_width
    end
  end
end
