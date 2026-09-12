require "rails_helper"

# 楽曲詳細ページ(Public::Songs#show)の参加状況表示・エントリー導線。
# 判定・エントリー登録はイベント楽曲一覧(events#show / join_confirm / join)と
# 同じものを再利用しているため、ここではブラウザ操作で実際に一連の流れが
# 動作すること・スマホ幅で崩れないことを確認する。
RSpec.describe "楽曲詳細ページの参加状況", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:member) { create(:customer, name: "参加太郎") }
  let(:community) { create(:community, owner_id: customer.id) }
  let(:event) do
    create(
      :event, :event_with_songs, customer: customer, community: community,
      event_start_time: 3.days.from_now, event_end_time: 3.days.from_now + 2.hours
    )
  end
  let(:song) { event.songs.first }

  before do
    CommunityOwner.find_or_create_by!(customer: customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  # この環境のheadless Chromeでは、画面外(要スクロール)にある要素へのネイティブclick
  # (Capybara#check・Selenium#click)が座標はイベント発生要素と一致するのに状態を変えない
  # ことがある(event_request_youtube_card_spec.rb等の既存コメントにある「送信ボタンの
  # data-confirmをwindow.confirm差し替えで回避」「send_keysのキー抜けをJSで直接値設定して
  # 回避」と同種の環境固有の制約)。楽曲詳細ページは情報テーブルが長く該当しやすいため、
  # チェックボックス操作・フォーム送信ボタンのクリックはJS経由で行う。
  def check_join_part(join_part)
    checkbox_id = "event_join_part_ids_#{join_part.id}"
    expect(page).to have_selector("##{checkbox_id}", visible: :all, wait: 10)
    page.execute_script(<<~JS)
      var el = document.getElementById('#{checkbox_id}');
      el.checked = true;
      el.dispatchEvent(new Event('change', { bubbles: true }));
    JS
  end

  def js_click_button(text)
    button = find_button(text)
    page.execute_script("arguments[0].click();", button.native)
  end

  it "募集中パートにチェックを入れて確認画面を経由し、参加登録が完了すること" do
    join_part = create(:join_part, song: song, join_part_name: "ボーカル")

    sign_in_via_form(customer)
    visit public_event_song_path(event, song)

    expect(page).to have_content("参加状況", wait: 10)
    expect(page).to have_content("募集中")

    check_join_part(join_part)
    # フォームのonSubmitがCheckJoin()(window.confirm)を呼ぶため、chat_event_link_preview_spec.rb等の
    # 既存specと同じくheadless Chromeのネイティブconfirm()を差し替えてから送信する。
    page.execute_script("window.confirm = function() { return true; };")
    js_click_button "参加確認画面へ"

    expect(page).to have_content("参加確認画面", wait: 10)
    expect(page).to have_content("ボーカル")

    page.execute_script("window.confirm = function() { return true; };")
    js_click_button "参加する"

    expect(page).to have_content("イベントへの参加が完了しました", wait: 10)
    expect(JoinPartCustomer.exists?(customer_id: customer.id, join_part_id: join_part.id)).to eq true
  end

  it "エントリー済みメンバーがアイコン・名前付きで表示されること" do
    join_part = create(:join_part, song: song, join_part_name: "ギター")
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
    create(:join_part_customer, join_part: join_part, customer: member)

    sign_in_via_form(customer)
    visit public_event_song_path(event, song)

    within(".song-part", text: "ギター") do
      expect(page).to have_link(member.name)
      expect(page).to have_selector("img")
    end
  end

  context "開催コミュニティに所属していない場合" do
    it "エントリーチェックボックスが表示されず、コミュニティ参加への案内が表示されること" do
      outsider = create(:customer)
      create(:join_part, song: song, join_part_name: "ドラム")

      sign_in_via_form(outsider)
      visit public_event_song_path(event, song)

      expect(page).to have_content("まずこちらのコミュニティに参加してください", wait: 10)
      expect(page).to have_no_selector("input[type='checkbox']")
    end
  end

  context "モバイル幅(375x812)" do
    it "参加状況が縦積みで表示され、横スクロールが増えないこと" do
      join_part = create(:join_part, song: song, join_part_name: "ベース")
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
      create(:join_part_customer, join_part: join_part, customer: member)

      sign_in_via_form(customer)
      # CDP override はページ描画済みの状態でしか効かないため sign_in 後・本画面 visit 前に適用する
      use_mobile_viewport(width: 375, height: 812)
      visit public_event_song_path(event, song)

      expect(page).to have_content("参加太郎", wait: 10)

      overflow = page.evaluate_script("document.documentElement.scrollWidth > document.documentElement.clientWidth + 1")
      expect(overflow).to eq false
    end
  end
end
