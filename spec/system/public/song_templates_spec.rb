require 'rails_helper'

RSpec.describe "楽曲テンプレート", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:community) { create(:community, owner_id: customer.id) }
  let(:event) { create(:event, :event_with_songs, customer: customer, community: community) }
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

  describe "テンプレート保存(Song詳細画面)" do
    it "保存ボタンが表示され、押下するとテンプレートが作成されflashが表示されること" do
      sign_in_via_form(customer)
      visit public_event_song_path(event, song)

      expect(page).to have_button("この曲をテンプレートとして保存", wait: 10)

      # chat_event_link_preview_spec.rbと同様の環境要因(ネイティブconfirm()の取りこぼし、
      # 固定ヘッダーとの座標重なりによるネイティブクリックの取りこぼし)を避けるため、
      # window.confirmを差し替えたうえでJSから直接クリックして確定的にテストする。
      page.execute_script("window.confirm = function() { return true; };")
      page.execute_script("document.getElementById('save-song-as-template-btn').click();")

      expect(page).to have_content("楽曲テンプレートを保存しました。", wait: 10)
      expect(SongTemplate.where(community: community, source_song: song).count).to eq 1
    end
  end

  describe "テンプレート適用(イベントフォーム)" do
    let!(:template) do
      create(
        :song_template, :with_chord_sheet, :with_tab_sheet,
        community: community, customer: customer,
        song_name: "丸の内サディスティック", artist_name: "椎名林檎",
        youtube_url: "https://youtube.com/watch?v=xxx", introduction: "紹介文です"
      )
    end

    def add_template_song
      select "丸の内サディスティック / 椎名林檎", from: "song-template-select"
      # click_buttonのネイティブ座標クリックが固定ヘッダー等と重なり取りこぼされることがある
      # 環境要因のため、保存ボタン・削除リンクと同様にJSから直接クリックして確定的にテストする。
      page.execute_script("document.getElementById('add-template-song-btn').click();")
    end

    it "対象Communityのテンプレートだけがselectの選択肢として表示されること" do
      other_community = create(:community)
      create(:song_template, community: other_community, song_name: "別コミュニティの曲")

      sign_in_via_form(customer)
      visit edit_public_event_path(event)

      within "#song-template-select" do
        expect(page).to have_content("丸の内サディスティック / 椎名林檎")
        expect(page).not_to have_content("別コミュニティの曲")
      end
    end

    it "テンプレートを選ぶと新しいSong行が追加され、各項目が反映されること" do
      sign_in_via_form(customer)
      visit edit_public_event_path(event)

      songs_before = page.all(".song-layout").count
      add_template_song

      expect(page).to have_selector(".song-layout", count: songs_before + 1, wait: 10)

      within all(".song-layout").last do
        expect(find("input[name*='[song_name]']").value).to eq "丸の内サディスティック"
        expect(find("input[name*='[artist_name]']").value).to eq "椎名林檎"
        expect(find("input[name*='[youtube_url]']").value).to eq "https://youtube.com/watch?v=xxx"
        expect(find("input[name*='[chord_sheet_url]']").value).to eq "https://example.com/chord-sheet"
        expect(find("input[name*='[tab_sheet_url]']").value).to eq "https://example.com/tab-sheet"
        expect(find("input[name*='[musical_key]']").value).to eq "G"
        expect(find("input[name*='[capo]']").value).to eq "2"
        expect(find("textarea[name*='[chord_sheet_note]']").value).to eq "初心者向けの簡単コード版です"
        expect(find("textarea[name*='[introduction]']").value).to eq "紹介文です"
        expect(find("input[name*='[performance_time]']").value).to eq ""
        expect(find("input[name*='[performance_start_time]']").value).to eq ""
      end
    end

    it "既存Song行の値は上書きされず、新しく追加した行だけへ反映されること" do
      sign_in_via_form(customer)
      visit edit_public_event_path(event)

      original_song_name = find("input[name*='[song_name]']", match: :first).value

      add_template_song

      expect(find("input[name*='[song_name]']", match: :first).value).to eq original_song_name
    end

    it "同じテンプレートを2回追加すると2行作成されること" do
      sign_in_via_form(customer)
      visit edit_public_event_path(event)

      songs_before = page.all(".song-layout").count
      add_template_song
      add_template_song

      expect(page).to have_selector(".song-layout", count: songs_before + 2, wait: 10)
    end

    it "通常の「曲を追加」ボタンが引き続き機能すること" do
      sign_in_via_form(customer)
      visit edit_public_event_path(event)

      songs_before = page.all(".song-layout").count
      click_link "曲を追加"

      expect(page).to have_selector(".song-layout", count: songs_before + 1, wait: 10)
      within all(".song-layout").last do
        expect(find("input[name*='[song_name]']").value).to eq ""
      end
    end

    it "375px幅でもフォームが崩れず横スクロールが発生しないこと" do
      sign_in_via_form(customer)
      # CDP override はページ描画済みの状態でしか効かないため sign_in 後・本画面 visit 前に適用する
      use_mobile_viewport(width: 375, height: 812)
      visit edit_public_event_path(event)

      expect(page).to have_selector("#song-template-select", wait: 10)
      body_scroll_width = page.evaluate_script("document.body.scrollWidth")
      # window.innerWidth は横溢れ分だけ広がって報告されるため、レイアウト
      # ビューポート幅は document.documentElement.clientWidth で取得する。
      viewport_width = page.evaluate_script("document.documentElement.clientWidth")
      expect(body_scroll_width).to be <= viewport_width + 1
    end
  end

  describe "テンプレート削除" do
    it "権限のあるユーザーには削除ボタンが表示され、削除するとselectから消えること" do
      template = create(:song_template, community: community, customer: customer, song_name: "削除対象の曲")

      sign_in_via_form(customer)
      visit edit_public_event_path(event)

      expect(page).to have_content("削除対象の曲", wait: 10)

      page.execute_script("window.confirm = function() { return true; };")
      page.execute_script("document.getElementById('delete-song-template-#{template.id}').click();")

      expect(page).to have_content("楽曲テンプレートを削除しました。", wait: 10)
      expect(SongTemplate.exists?(template.id)).to eq false
      expect(Event.exists?(event.id)).to eq true
    end

    it "削除権限がないユーザーには削除ボタンが表示されないこと" do
      # コミュニティ管理者ではなく「自分が作成したイベント」を編集できるだけの
      # 一般メンバーを想定する(can_edit_event?はイベント作成者本人もtrueを返すため、
      # コミュニティ管理者でない一般メンバーでもedit画面には到達できる)。
      event_creator = create(:customer)
      own_event = create(:event, :event_with_songs, customer: event_creator, community: community)
      CommunityCustomer.find_or_create_by!(customer: event_creator, community: community)
      create(:song_template, community: community, customer: customer, song_name: "他人のテンプレート")

      sign_in_via_form(event_creator)
      visit edit_public_event_path(own_event)

      within ".song-template-picker__list" do
        expect(page).to have_content("他人のテンプレート")
        expect(page).not_to have_link("削除")
      end
    end
  end
end
