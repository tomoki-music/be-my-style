require "rails_helper"

# 編集画面の「コミュニティを削除」→ 確認画面 → キャンセル / 削除 の画面遷移。データはすべて架空。
RSpec.describe "Business コミュニティ削除の画面遷移", type: :system do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let!(:community) { create(:community, owner: owner, domain: business_domain, name: "削除テスト工房") }

  before do
    CommunityCustomer.create!(community: community, customer: owner)
    Project.create!(community: community, customer: owner, title: "工房の企画")
    visit new_business_customer_session_path
    fill_in "customer_email", with: owner.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_css(".ba-main")
  end

  def open_confirmation
    visit edit_business_community_path(community)
    within("#community-delete") { click_link "コミュニティを削除" }
    expect(page).to have_content("「削除テスト工房」を削除しますか？")
    expect(page).to have_content("プロジェクト 1件")
  end

  it "キャンセルすると編集画面に戻り、何も削除されない" do
    open_confirmation

    expect { click_link "キャンセル" }.not_to change(Community, :count)

    expect(page).to have_current_path(edit_business_community_path(community))
    expect(Project.where(community_id: community.id).count).to eq 1
  end

  it "削除するとコミュニティ一覧に完了メッセージが出て、一覧から消える" do
    open_confirmation

    expect { click_button "削除する" }.to change(Community, :count).by(-1)

    expect(page).to have_current_path(business_communities_path)
    expect(page).to have_content("コミュニティ「削除テスト工房」を削除しました。")
    expect(page).not_to have_link("削除テスト工房")
  end
end
