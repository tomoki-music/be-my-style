require 'rails_helper'

RSpec.describe "コミュニティのイベント編集者ロール", type: :system do
  let(:owner) { create(:customer, :customer_with_parts) }
  let(:community) { create(:community, owner_id: owner.id) }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }
  # マネージャー(is_owner: manager)は管理画面から任命される正式な役職で、
  # 実権限判定はCommunityEventEditorへの登録で行う(公開側の自己申告制は廃止済み)。
  let(:manager_customer) { create(:customer, :customer_with_parts, name: "編集たろう", is_owner: :manager) }
  let(:member_customer) { create(:customer, :customer_with_parts, name: "一般はなこ") }

  before do
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: manager_customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: member_customer, community: community)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  it "マネージャー(is_owner: manager)かつCommunityEventEditor登録済みにはイベント編集ボタンが表示され、コピー・削除ボタンは表示されないこと" do
    CommunityEventEditor.create!(customer: manager_customer, community: community)

    sign_in_via_form(manager_customer)
    visit public_event_path(event)

    expect(page).to have_link("イベントの編集")
    expect(page).not_to have_link("コピーして新規作成")
    expect(page).not_to have_link("イベント削除")
  end

  it "CommunityEventEditorレコードだけを持つ一般メンバー(is_owner: general)にはイベント編集ボタンが表示されないこと" do
    legacy_event_editor_customer = create(:customer, :customer_with_parts, name: "旧編集者次郎")
    CommunityCustomer.find_or_create_by!(customer: legacy_event_editor_customer, community: community)
    CommunityEventEditor.create!(customer: legacy_event_editor_customer, community: community)

    sign_in_via_form(legacy_event_editor_customer)
    visit public_event_path(event)

    expect(page).not_to have_link("イベントの編集")
  end

  it "一般メンバーにはイベント編集ボタンが表示されないこと" do
    sign_in_via_form(member_customer)
    visit public_event_path(event)

    expect(page).not_to have_link("イベントの編集")
  end

  it "メンバーカードに「イベント編集者に設定」ボタンが表示されず、プロフィール画面へのリンクは表示されること" do
    sign_in_via_form(owner)
    visit public_community_path(community)

    within(find(".card.center", text: member_customer.name)) do
      expect(page).to have_link("プロフィール画面へ")
      expect(page).not_to have_button("イベント編集者に設定")
      expect(page).not_to have_button("イベント編集者に追加")
    end
  end

  it "オーナーで閲覧しても「イベント編集者管理」が表示されないこと" do
    CommunityEventEditor.create!(customer: manager_customer, community: community)

    sign_in_via_form(owner)
    visit public_community_path(community)

    expect(page).not_to have_content("イベント編集者管理")
    expect(page).not_to have_content("イベントを作成・編集できるメンバーを設定します。")
    expect(page).not_to have_css(".community-event-editors")
    expect(page).not_to have_button("イベント編集者に追加")
    expect(page).not_to have_link("解除")
  end

  it "一般メンバーで閲覧しても「イベント編集者」が表示されないこと" do
    CommunityEventEditor.create!(customer: manager_customer, community: community)

    sign_in_via_form(member_customer)
    visit public_community_path(community)

    expect(page).not_to have_content("イベント編集者")
    expect(page).not_to have_css(".community-event-editors")
  end

  it "コミュニティ一覧ページで役職案内が表示されること" do
    sign_in_via_form(member_customer)
    visit public_communities_path

    expect(page).to have_content("役職について")
    expect(page).to have_content("管理者")
    expect(page).to have_content("オーナー")
    expect(page).to have_content("マネージャー")
    expect(page).to have_content("一般メンバー")
  end

  it "役職案内の「マネージャー」説明が、管理者からの割り当てであることを示していること" do
    sign_in_via_form(member_customer)
    visit public_communities_path

    expect(page).to have_content("管理者から担当コミュニティを割り当てられる役職です")
  end

  describe "マネージャーバッジの表示" do
    it "is_owner: managerのメンバーには「マネージャー」バッジが表示されること" do
      sign_in_via_form(owner)
      # 会員一覧は1ページ3件のため、事前に登録済みのowner/manager_customer/member_customerで
      # 1ページ目が埋まる。ここではmanager_customer自体が対象。
      visit public_community_path(community, page: 1)

      within(find(".card.center", text: manager_customer.name)) do
        badge = find(".avatar-role-badge--manager")
        expect(badge.text).to eq "マネージャー"
      end
    end

    it "一般会員にはバッジが表示されないこと" do
      sign_in_via_form(owner)
      visit public_community_path(community)

      within(find(".card.center", text: member_customer.name)) do
        expect(page).not_to have_css(".avatar-role-badge")
      end
    end

    it "管理者・オーナーの既存バッジ表示は変わらないこと" do
      admin_customer = create(:customer, :customer_with_parts, name: "管理花子", is_owner: :admin)
      owner_role_customer = create(:customer, :customer_with_parts, name: "オーナー三郎", is_owner: :community_owner)
      CommunityCustomer.find_or_create_by!(customer: admin_customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: owner_role_customer, community: community)

      sign_in_via_form(owner)
      # 会員一覧は1ページ3件のため、事前に登録済みのowner/manager_customer/member_customerで
      # 1ページ目が埋まる。新規追加した2名は2ページ目に表示される。
      visit public_community_path(community, page: 2)

      within(find(".card.center", text: admin_customer.name)) do
        expect(find(".avatar-role-badge--admin").text).to eq "管理者"
      end
      within(find(".card.center", text: owner_role_customer.name)) do
        expect(find(".avatar-role-badge--owner").text).to eq "オーナー"
      end
    end
  end

  context "モバイル幅表示", js: true do
    it "375px幅でも役職案内カードが横スクロールを発生させず表示されること" do
      sign_in_via_form(member_customer)
      # resize_to はこの環境の headless Chrome で最小ウィンドウ幅(約500px)へ
      # 丸められスマホ幅を再現できない。CDP override で真の375px幅を適用する。
      use_mobile_viewport(width: 375, height: 812)
      visit public_communities_path

      expect(page).to have_content("役職について", wait: 10)
      body_scroll_width = page.evaluate_script("document.body.scrollWidth")
      # window.innerWidth は横溢れが起きると溢れ幅の分だけ広がって報告されるため
      # 基準に使えない(横スクロールがあっても body.scrollWidth と一致してしまう)。
      # レイアウトビューポート幅は document.documentElement.clientWidth で取得する。
      viewport_width = page.evaluate_script("document.documentElement.clientWidth")
      expect(body_scroll_width).to be <= viewport_width
    end
  end
end
