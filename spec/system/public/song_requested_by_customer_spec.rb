require 'rails_helper'

RSpec.describe "楽曲のリクエストした人", type: :system do
  before { driven_by :selenium_chrome_headless }

  let(:customer) { create(:customer) }
  let(:community) { create(:community, owner_id: customer.id) }
  let(:member) { create(:customer, name: "参加太郎") }
  let(:outsider) { create(:customer, name: "部外者花子") }
  let(:event) { create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { event.songs.first }

  before do
    CommunityOwner.find_or_create_by!(customer: customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: member, community: community)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  def requester_select(index = 0)
    all(".song-layout")[index].find("select[name*='requested_by_customer_id']")
  end

  describe "新規作成画面" do
    it "コミュニティが確定している場合はリクエストした人を選択できること" do
      sign_in_via_form(customer)
      visit new_public_event_path(community_id: community.id)

      expect(requester_select.disabled?).to eq false
      select "参加太郎", from: requester_select[:id]
      expect(requester_select.value).to eq member.id.to_s
    end

    it "コミュニティが未確定の場合はリクエストした人を選択できないこと" do
      sign_in_via_form(customer)
      visit new_public_event_path

      expect(requester_select.disabled?).to eq true
      expect(page).to have_content("コミュニティ確定後に設定できます")
    end
  end

  describe "編集画面の候補一覧" do
    let!(:deleted_member) { create(:customer, name: "退会済み花子") }

    before do
      CommunityCustomer.find_or_create_by!(customer: deleted_member, community: community)
      deleted_member.update!(is_deleted: true)
    end

    it "対象コミュニティの有効メンバーだけが候補に出ること" do
      sign_in_via_form(customer)
      visit edit_public_event_path(event)

      within requester_select do
        expect(page).to have_content("指定なし")
        expect(page).to have_content("参加太郎")
        expect(page).not_to have_content("部外者花子")
        expect(page).not_to have_content("退会済み花子")
      end
    end

    it "指定なしを選択して保存できること" do
      song.update!(requested_by_customer_id: member.id)
      sign_in_via_form(customer)
      visit edit_public_event_path(event)

      select "指定なし", from: requester_select[:id]
      page.execute_script("window.confirm = function() { return true; };")
      click_button "イベントを登録"

      expect(page).to have_content("イベントの編集が完了しました", wait: 10)
      expect(song.reload.requested_by_customer_id).to be_nil
    end
  end

  describe "動的に追加した楽曲行" do
    it "cocoonで追加した楽曲行でもリクエストした人を選択できること" do
      sign_in_via_form(customer)
      visit edit_public_event_path(event)

      songs_before = page.all(".song-layout").count
      click_link "曲を追加"
      expect(page).to have_selector(".song-layout", count: songs_before + 1, wait: 10)

      new_row_select = requester_select(songs_before)
      expect(new_row_select.disabled?).to eq false
      select "参加太郎", from: new_row_select[:id]
      expect(new_row_select.value).to eq member.id.to_s
    end
  end

  describe "イベント詳細画面での表示" do
    it "リクエスト者が設定された曲には表示され、未設定の曲には表示されないこと" do
      create(:song, event: event, song_name: "未設定の曲")
      song.update!(requested_by_customer_id: member.id)

      sign_in_via_form(customer)
      visit public_event_path(event)

      expect(page).to have_selector(".song-requester", text: "参加太郎", wait: 10)

      row = all(".event-songs-table tbody tr").find { |tr| tr.has_content?("未設定の曲") }
      expect(row).not_to have_selector(".song-requester")
    end
  end

  context "モバイル幅(375x812)での表示" do
    before { page.current_window.resize_to(375, 812) }

    it "リクエスト表示によって横スクロールが増えず崩れないこと" do
      song.update!(requested_by_customer_id: member.id)

      sign_in_via_form(customer)
      visit public_event_path(event)

      expect(page).to have_selector(".song-requester", text: "参加太郎", wait: 10)

      requester_node = find(".song-requester")
      client_width = page.evaluate_script("document.documentElement.clientWidth")
      node_right = requester_node.evaluate_script("this.getBoundingClientRect().right")
      expect(node_right).to be <= client_width + 1
    end
  end
end
