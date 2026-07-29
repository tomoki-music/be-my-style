require "rails_helper"

# みんなのリクエスト(Requestモデル、"リクエストする🎵"導線)にYouTube URLを含めて投稿すると、
# イベント画面にサムネイルカードが表示されることを実ブラウザで検証する。
# PR #134はSong#youtube_url(イベント編集画面、オーナー限定)のみに対応しており、
# 全参加者が使えるみんなのリクエストにはカード表示が無かった(本Specが再現・回帰防止対象)。
RSpec.describe "みんなのリクエストのYouTubeカード", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:owner) { create(:customer, :customer_with_parts) }
  let(:community) { create(:community) }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }

  before do
    owner.create_subscription!(status: "active", plan: "core")
    owner.update!(onboarding_done: true)
    community.update!(owner_id: owner.id)
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  # 送信ボタンにdata-confirmが付いており、headless Chromeのネイティブconfirm()は
  # 自動でacceptされないため、window.confirmを差し替えてから送信する
  # (chat_event_link_preview_spec.rbの既存対応と同じ理由・同じ手法)。
  def submit_request_form
    page.execute_script("window.confirm = function() { return true; };")
    page.execute_script("document.querySelector('.event-request-btn').click();")
  end

  # send_keysでの逐次入力は、この環境ではキー抜け(先頭・末尾数文字の欠落)が発生することが
  # あるため、chat_quote_reply_spec.rb等と同様にJSで直接値を設定する。
  def fill_in_request_input(content)
    page.execute_script(<<~JS)
      (function () {
        var el = document.querySelector('#input_request');
        el.value = #{content.to_json};
        el.dispatchEvent(new Event('input'));
      })();
    JS
  end

  it "「リクエストする」フォームからYouTube URLを投稿すると、リロードなしでサムネイルカードが表示される" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    fill_in_request_input("この曲でお願いします！ https://www.youtube.com/watch?v=abcdefghijk")
    submit_request_form

    expect(page).to have_selector(".event-song-youtube-card", wait: 10)
    within all(".request-content").first do
      expect(page).to have_link(href: "https://www.youtube.com/watch?v=abcdefghijk")
    end

    visit public_event_path(event)
    expect(page).to have_selector(".event-song-youtube-card")
  end

  it "URLを含まないリクエストではカードが表示されない" do
    sign_in_via_form(owner)
    visit public_event_path(event)

    fill_in_request_input("オリジナル曲を１曲お願いします！")
    submit_request_form

    expect(page).to have_content("オリジナル曲を１曲お願いします！", wait: 10)
    expect(page).not_to have_selector(".event-song-youtube-card")
  end

  context "モバイル幅(375x812)での表示" do
    before { page.current_window.resize_to(375, 812) }

    # 注記: このheadless Chrome環境ではresize_to(375, 812)を呼んでも
    # document.documentElement.clientWidthが500になる(ウィンドウ最小幅の環境制約)。
    # また、このページには本PRと無関係な既存の水平オーバーフローが元々存在する
    # (フォント計測用と見られるposition:absolute; font-size:300pxのspan要素によるもの、
    # カード投稿前でも発生することを確認済み)。そのため「ページ全体で横スクロールが
    # 一切無い」ことではなく、「カード追加によって横スクロール量が増えていない」こと、
    # および「カード自身が投稿の幅内に収まっている」ことを検証する。
    it "カードがモバイル幅に収まり、追加の横スクロールを発生させず、既存UIと重ならないこと" do
      sign_in_via_form(owner)
      visit public_event_path(event)
      baseline_scroll_width = page.evaluate_script("document.documentElement.scrollWidth")
      client_width = page.evaluate_script("document.documentElement.clientWidth")

      fill_in_request_input("この曲でお願いします！ https://www.youtube.com/watch?v=abcdefghijk")
      submit_request_form

      expect(page).to have_selector(".event-song-youtube-card", wait: 10)

      # カード追加によってページの横幅が広がっていないこと(既存の横スクロールを悪化させない)
      scroll_width = page.evaluate_script("document.documentElement.scrollWidth")
      expect(scroll_width).to be <= baseline_scroll_width

      card = find(".event-song-youtube-card")
      request_content = find(".request-content")

      # サムネイルがカード幅内に収まっていること
      card_width = card.evaluate_script("this.getBoundingClientRect().width")
      thumbnail_width = find(".event-song-youtube-card-thumbnail").evaluate_script("this.getBoundingClientRect().width")
      expect(thumbnail_width).to be <= card_width

      # カード自体がビューポート幅・投稿(.request-content)の幅内に収まっていること(はみ出し無し)
      card_right = card.evaluate_script("this.getBoundingClientRect().right")
      content_right = request_content.evaluate_script("this.getBoundingClientRect().right")
      expect(card_right).to be <= client_width + 1
      expect(card_right).to be <= content_right + 1 # サブピクセル誤差許容

      # 削除ボタンとカードが重なっていないこと(縦方向に完全分離)
      delete_btn = find(".request-delete")
      card_top = card.evaluate_script("this.getBoundingClientRect().top")
      delete_bottom = delete_btn.evaluate_script("this.getBoundingClientRect().bottom")
      expect(card_top).to be >= delete_bottom

      # 「YouTubeで見る」リンクがタップ可能な最小サイズ(44px四方目安)以上であること
      card_height = card.evaluate_script("this.getBoundingClientRect().height")
      expect(card_height).to be >= 44

      # リロード後も表示され、横スクロール量が増えていないこと
      visit public_event_path(event)
      expect(page).to have_selector(".event-song-youtube-card")
      scroll_width_after_reload = page.evaluate_script("document.documentElement.scrollWidth")
      expect(scroll_width_after_reload).to be <= baseline_scroll_width
    end

    it "URLを含まないリクエストではモバイル幅でもカードが表示されないこと" do
      sign_in_via_form(owner)
      visit public_event_path(event)

      fill_in_request_input("オリジナル曲を１曲お願いします！")
      submit_request_form

      expect(page).to have_content("オリジナル曲を１曲お願いします！", wait: 10)
      expect(page).not_to have_selector(".event-song-youtube-card")
    end
  end
end
