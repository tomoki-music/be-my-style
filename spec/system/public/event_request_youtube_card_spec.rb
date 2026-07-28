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
end
