require "rails_helper"

# BeMyStyleイベントリンクカード(Phase4-D)の表示を実ブラウザで検証する。
# イベント解決はChat::LinkPreviewSyncService内で同期的に行われる(Job非経由)ため、
# chat_link_preview_spec.rbと同様、既にstatus: fetchedなChatMessageLinkPreviewを
# 直接作成し、「サーバーが返したHTMLがそのまま表示されること」だけを確認する。
RSpec.describe "イベントリンクカード", type: :system do
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

  # 投稿ボタンにdata-confirmが付いている。本来はaccept_confirmで包む想定だが、
  # 手元のChrome/Seleniumの組み合わせではネイティブconfirm()がSeleniumの
  # アラート処理より先に消えてしまい"no such alert"で失敗する(既存の
  # chat_quote_reply_spec.rbの同種テストも同じ理由で現在失敗する、本PRの
  # 変更とは無関係な環境要因)。window.confirmを常にtrueへ差し替えた上で、
  # ヘッダーメニュー領域がこの環境ではCSS未適用のまま送信ボタンへ重なり、
  # Seleniumのネイティブ座標クリックが取りこぼされることがあるため、
  # 要素へ直接クリックイベントを発火させて確定的にテストする(実際の
  # Railsサーバー+実ブラウザではこの重なりは発生せず、ネイティブクリックでも
  # 直後にカードが表示されることを実機確認済み)。
  def submit_chat_form
    page.execute_script("window.confirm = function() { return true; };")
    page.execute_script("document.querySelector('.form-container .chat-form-btn').click();")
  end

  def create_event(**attrs)
    create(:event, :event_with_songs, customer: event_owner, community: community, **attrs)
  end

  def event_url_for(event)
    "https://www.example.com/public/events/#{event.id}"
  end

  def create_link_preview(chat_message, event, **attrs)
    create(:chat_message_link_preview, :event, chat_message: chat_message,
                                                url: event_url_for(event),
                                                external_id: event.id.to_s,
                                                title: event.event_name,
                                                author_name: event.community.name,
                                                **attrs)
  end

  it "開催予定イベントのカードが画像・イベント名・コミュニティ名・日時・会場・参加費・バッジ・詳細リンク付きで表示されること" do
    event = create_event(event_name: "セッション会", place: "スタジオA", entrance_fee: 1500,
                          event_start_time: 3.days.from_now, event_end_time: 3.days.from_now + 2.hours,
                          event_entry_deadline: 2.days.from_now)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                                content: "見て #{event_url_for(event)}")
    create_link_preview(target, event)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".link-preview-card--event", wait: 10)
      expect(page).to have_content("セッション会")
      expect(page).to have_content(community.name)
      expect(page).to have_content("スタジオA")
      expect(page).to have_content("1500円")
      expect(page).to have_content("開催予定")
      expect(page).to have_link("イベント詳細を見る ↗", href: public_event_path(event))
    end
  end

  it "終了済みイベントは「終了済み」バッジが表示されること" do
    event = create_event(event_start_time: 3.days.ago, event_end_time: 2.days.ago, event_entry_deadline: 4.days.ago)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: event_url_for(event))
    create_link_preview(target, event)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_content("終了済み", wait: 10)
    end
  end

  it "開催中イベントは「開催中」バッジが表示されること" do
    event = create_event(event_start_time: 1.hour.ago, event_end_time: 1.hour.from_now, event_entry_deadline: 2.days.ago)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: event_url_for(event))
    create_link_preview(target, event)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_content("開催中", wait: 10)
    end
  end

  it "参加締切を過ぎたイベントは「募集終了」バッジが表示されること" do
    event = create_event(event_start_time: 1.day.from_now, event_end_time: 1.day.from_now + 2.hours, event_entry_deadline: 1.hour.ago)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: event_url_for(event))
    create_link_preview(target, event)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_content("募集終了", wait: 10)
    end
  end

  it "画像未添付イベントはno-image画像が表示されること" do
    event = create_event
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: event_url_for(event))
    create_link_preview(target, event)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".link-preview-card--event img", wait: 10)
    end
  end

  it "長いイベント名・コミュニティ名・会場名でもカード幅が広がらないこと" do
    long_community = create(:community, name: "あ" * 30)
    long_event = create(:event, :event_with_songs, customer: event_owner, community: long_community,
                                                    event_name: "い" * 60, place: "う" * 60)
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: event_url_for(long_event))
    create(:chat_message_link_preview, :event, chat_message: target, url: event_url_for(long_event),
                                                external_id: long_event.id.to_s,
                                                title: long_event.event_name, author_name: long_community.name)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      card_width = page.evaluate_script("document.querySelector('.link-preview-card--event').getBoundingClientRect().width")
      expect(card_width).to be <= 320
    end
  end

  it "Event削除後はスナップショットによるフォールバックカードが表示され、詳細リンクが表示されないこと" do
    event = create_event(event_name: "削除予定イベント")
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: event_url_for(event))
    create_link_preview(target, event)
    deleted_event_path = public_event_path(event)
    event.destroy!

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_content("このイベントは削除されました", wait: 10)
      expect(page).to have_content("削除予定イベント")
      expect(page).not_to have_link(href: deleted_event_path)
    end
  end

  it "モバイル幅(375px)でもカードが横スクロールを発生させず表示されること" do
    event = create_event(event_name: "モバイル確認イベント")
    target = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: event_url_for(event))
    create_link_preview(target, event)

    page.driver.browser.manage.window.resize_to(375, 812)
    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    within "#chat-message-#{target.id}" do
      expect(page).to have_selector(".link-preview-card--event", wait: 10)
    end
    body_scroll_width = page.evaluate_script("document.body.scrollWidth")
    viewport_width = page.evaluate_script("window.innerWidth")
    expect(body_scroll_width).to be <= viewport_width
  end

  it "スレッドパネル内の返信でもイベントカードが表示されること" do
    root = create(:chat_message, customer: other_customer, chat_room: chat_room, content: "元メッセージ")
    event = create_event(event_name: "スレッド内イベント")
    reply = create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room,
                                              content: event_url_for(event), reply_to_chat_message: root)
    create_link_preview(reply, event)

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)

    expect(page).to have_selector(".thread-replies-button", wait: 10)
    page.evaluate_script("document.querySelector('.thread-replies-button').click();")
    expect(page).to have_selector("#thread-panel:not([hidden])", wait: 10)

    within "#thread-panel-body" do
      expect(page).to have_selector(".link-preview-card--event", wait: 10)
      expect(page).to have_content("スレッド内イベント")
    end
  end

  it "イベントURLを新規投稿すると、リロードなしで送信直後にイベントカードが表示されること" do
    create(:chat_message, customer: other_customer, chat_room: chat_room, content: "こんにちは")
    event = create_event(event_name: "送信直後表示確認イベント")

    sign_in_via_form(customer)
    visit public_chat_room_path(chat_room, customer_id: other_customer.id)
    expect(page).to have_selector(".form-container .chat-form-btn", wait: 10)

    fill_in_markdown_textarea(".form-container .markdown-textarea", "見て #{event_url_for(event)}")
    submit_chat_form

    expect(page).to have_selector(".link-preview-card--event", wait: 10)
    expect(page).to have_content("送信直後表示確認イベント")
  end
end
