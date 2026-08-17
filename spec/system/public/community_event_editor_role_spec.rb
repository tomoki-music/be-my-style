require 'rails_helper'

RSpec.describe "コミュニティのイベント編集者ロール", type: :system do
  let(:owner) { create(:customer, :customer_with_parts) }
  let(:community) { create(:community, owner_id: owner.id) }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }
  let(:event_editor_customer) { create(:customer, :customer_with_parts, name: "編集たろう") }
  let(:member_customer) { create(:customer, :customer_with_parts, name: "一般はなこ") }

  before do
    CommunityOwner.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: event_editor_customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: member_customer, community: community)
  end

  def sign_in_via_form(target_customer)
    visit new_customer_session_path
    fill_in "customer_email", with: target_customer.email
    fill_in "customer_password", with: "password"
    click_button "ログイン"
    expect(page).to have_content("ログインしました", wait: 10)
  end

  it "イベント編集者にはイベント編集ボタンが表示され、コピー・削除ボタンは表示されないこと" do
    CommunityEventEditor.create!(customer: event_editor_customer, community: community)

    sign_in_via_form(event_editor_customer)
    visit public_event_path(event)

    expect(page).to have_link("イベントの編集")
    expect(page).not_to have_link("コピーして新規作成")
    expect(page).not_to have_link("イベント削除")
  end

  it "一般メンバーにはイベント編集ボタンが表示されないこと" do
    sign_in_via_form(member_customer)
    visit public_event_path(event)

    expect(page).not_to have_link("イベントの編集")
  end

  it "オーナーがメンバーへイベント編集者を設定できること" do
    sign_in_via_form(owner)
    visit public_community_path(community)

    within(".community-event-editors") do
      expect(page).to have_content("イベント編集者管理")
      select member_customer.name, from: "customer_id"
      click_button "イベント編集者に追加"
    end

    expect(page).to have_content("イベント編集者に設定しました")
    within ".community-event-editors" do
      expect(page).to have_content(member_customer.name)
    end
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

  it "一般メンバーには「イベント編集者管理」フォームが表示されず、解除ボタンも表示されないこと" do
    CommunityEventEditor.create!(customer: event_editor_customer, community: community)

    sign_in_via_form(member_customer)
    visit public_community_path(community)

    within(".community-event-editors") do
      expect(page).to have_content("イベント編集者")
      expect(page).not_to have_content("イベント編集者管理")
      expect(page).not_to have_button("イベント編集者に追加")
      expect(page).not_to have_link("解除")
    end
  end

  it "コミュニティ一覧ページで役職案内が表示されること" do
    sign_in_via_form(member_customer)
    visit public_communities_path

    expect(page).to have_content("役職について")
    expect(page).to have_content("管理者")
    expect(page).to have_content("オーナー")
    expect(page).to have_content("イベント編集者")
    expect(page).to have_content("一般メンバー")
  end

  describe "マネージャーバッジの表示" do
    it "is_owner: managerのメンバーには「マネージャ」バッジが表示されること" do
      manager_customer = create(:customer, :customer_with_parts, name: "マネ次郎", is_owner: :manager)
      CommunityCustomer.find_or_create_by!(customer: manager_customer, community: community)

      sign_in_via_form(owner)
      # 会員一覧は1ページ3件のため、事前に登録済みのowner/event_editor_customer/member_customerで
      # 1ページ目が埋まる。新規追加したmanager_customerは2ページ目に表示される。
      visit public_community_path(community, page: 2)

      within(find(".card.center", text: manager_customer.name)) do
        badge = find(".avatar-role-badge--manager")
        expect(badge.text).to eq "マネージャ"
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
      # 会員一覧は1ページ3件のため、事前に登録済みのowner/event_editor_customer/member_customerで
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
      page.driver.browser.manage.window.resize_to(375, 812)
      visit public_communities_path

      expect(page).to have_content("役職について", wait: 10)
      body_scroll_width = page.evaluate_script("document.body.scrollWidth")
      viewport_width = page.evaluate_script("window.innerWidth")
      expect(body_scroll_width).to be <= viewport_width
    end
  end
end
