require "rails_helper"

# 編集画面の「プロジェクトを削除」→ 確認画面 → キャンセル / 削除 の画面遷移。データはすべて架空。
RSpec.describe "Business プロジェクト削除の画面遷移", type: :system do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:admin_customer) { create(:customer, domain_name: "business", onboarding_done: true, is_owner: :admin) }
  let(:creator) { create(:customer, domain_name: "business", onboarding_done: true) }
  let!(:community) { create(:community, owner: owner, domain: business_domain, name: "削除テスト工房") }
  let!(:project) { Project.create!(community: community, customer: creator, title: "工房の企画") }
  let!(:other_project) { Project.create!(community: community, customer: owner, title: "残る企画") }

  before do
    [owner, creator].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
  end

  def log_in(customer)
    visit new_business_customer_session_path
    fill_in "customer_email", with: customer.email
    fill_in "customer_password", with: "password"
    click_button "ログインする"
    expect(page).to have_css(".ba-main")
  end

  def open_confirmation
    visit edit_business_project_path(project)
    within("#project-delete") { click_link "プロジェクトを削除" }
    expect(page).to have_content("「工房の企画」を削除しますか？")
    expect(page).to have_content("スレッド内の投稿 0件")
  end

  [["親コミュニティのオーナー", :owner], ["管理者", :admin_customer]].each do |label, actor|
    context label do
      before { log_in(public_send(actor)) }

      it "キャンセルすると編集画面に戻り、何も削除されない" do
        open_confirmation

        expect { click_link "キャンセル" }.not_to change(Project, :count)

        expect(page).to have_current_path(edit_business_project_path(project))
      end

      it "削除すると親コミュニティに完了メッセージが出て、ほかのプロジェクトは残る" do
        open_confirmation

        expect { click_button "削除する" }.to change(Project, :count).by(-1)

        expect(page).to have_current_path(business_community_path(community))
        expect(page).to have_content("プロジェクト「工房の企画」を削除しました。")
        expect(page).to have_content("残る企画")
        expect(page).not_to have_link("工房の企画")
      end
    end
  end

  it "作成者のみの場合は編集画面に削除の枠が出ない" do
    log_in(creator)
    visit edit_business_project_path(project)

    expect(page).to have_content("プロジェクト編集")
    expect(page).not_to have_css("#project-delete")
  end
end
