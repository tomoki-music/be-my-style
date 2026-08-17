require 'rails_helper'

RSpec.describe "Admin::Customers", type: :request do
  describe "GET /index" do
    pending "add some examples (or delete) #{__FILE__}"
  end

  let(:admin) { FactoryBot.create(:admin) }
  let(:customer) { FactoryBot.create(:customer) }
  let(:community_a) { FactoryBot.create(:community) }
  let(:community_b) { FactoryBot.create(:community) }

  before do
    # Admin::CustomersControllerはApplicationController共通のauthenticate_customer!を
    # skipしていない(Admin::EventsController等とは異なる既存の挙動)ため、
    # 管理者ログインに加えてCustomerのログインも必要になる。
    sign_in FactoryBot.create(:customer)
    sign_in admin
  end

  def owned_community_checkbox(body, community)
    Nokogiri::HTML(body).at_css(
      "input[type=checkbox][name='customer[owned_community_ids][]'][value='#{community.id}']"
    )
  end

  describe "GET /admin/customers/:id/edit のUI" do
    it "管理者設定にマネージャーの選択肢が表示されること" do
      get edit_admin_customer_path(customer)

      option = Nokogiri::HTML(response.body).at_css("select#customer_is_owner option[value='manager']")
      expect(option).to be_present
      expect(option.text).to eq "マネージャー（イベント編集のみ可）"
    end

    it "「管理コミュニティ」欄が1箇所だけ表示されること" do
      get edit_admin_customer_path(customer)

      expect(response.body.scan("管理コミュニティ").size).to eq 1
    end

    it "「イベント編集コミュニティ」欄が表示されないこと" do
      get edit_admin_customer_path(customer)

      expect(response.body).not_to include("イベント編集コミュニティ")
    end

    it "オーナー・マネージャーの説明文が表示されること" do
      get edit_admin_customer_path(customer)

      expect(response.body).to include("コミュニティオーナーはイベントの作成・編集・削除ができます。")
      expect(response.body).to include("マネージャーは既存イベントや楽曲の編集のみ行えます。")
    end
  end

  describe "community_ownerを選択した場合" do
    before { customer.update!(is_owner: :community_owner) }

    it "管理コミュニティの保存でcommunity_ownersへ登録されること" do
      patch admin_customer_path(customer), params: {
        customer: { is_owner: "community_owner", owned_community_ids: [community_a.id] }
      }

      expect(customer.reload.owned_communities).to contain_exactly(community_a)
    end

    it "community_event_editorsへは登録されないこと" do
      patch admin_customer_path(customer), params: {
        customer: { is_owner: "community_owner", owned_community_ids: [community_a.id] }
      }

      expect(customer.reload.edited_communities).to be_empty
    end

    it "複数コミュニティを保存できること" do
      patch admin_customer_path(customer), params: {
        customer: { is_owner: "community_owner", owned_community_ids: [community_a.id, community_b.id] }
      }

      expect(customer.reload.owned_communities).to contain_exactly(community_a, community_b)
    end

    it "チェック解除で解除できること" do
      CommunityOwner.create!(customer: customer, community: community_a)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "community_owner", owned_community_ids: [""] }
      }

      expect(customer.reload.owned_communities).to be_empty
    end
  end

  describe "managerを選択した場合" do
    it "管理コミュニティの保存でcommunity_event_editorsへ登録されること" do
      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_a.id] }
      }

      expect(customer.reload.edited_communities).to contain_exactly(community_a)
    end

    it "community_ownersへは登録されないこと" do
      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_a.id] }
      }

      expect(customer.reload.owned_communities).to be_empty
    end

    it "複数コミュニティを保存できること" do
      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_a.id, community_b.id] }
      }

      expect(customer.reload.edited_communities).to contain_exactly(community_a, community_b)
    end

    it "チェック解除で解除できること" do
      customer.update!(is_owner: :manager)
      CommunityEventEditor.create!(customer: customer, community: community_a)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [""] }
      }

      expect(customer.reload.edited_communities).to be_empty
    end

    it "保存後に管理コミュニティのチェック状態が再表示されること" do
      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_a.id] }
      }

      get edit_admin_customer_path(customer)

      expect(owned_community_checkbox(response.body, community_a)["checked"]).to eq "checked"
    end

    it "コミュニティ未選択でも保存できること" do
      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [""] }
      }

      expect(customer.reload.is_owner).to eq "manager"
      expect(response).to redirect_to(admin_homes_top_path)
    end

    it "担当コミュニティを一部だけ解除すると、解除した分だけ削除され継続選択分は残ること" do
      customer.update!(is_owner: :manager)
      CommunityEventEditor.create!(customer: customer, community: community_a)
      CommunityEventEditor.create!(customer: customer, community: community_b)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_b.id] }
      }

      expect(customer.reload.edited_communities).to contain_exactly(community_b)
    end

    it "廃止済みの公開画面機能などで作成された古いCommunityEventEditorレコードは、" \
       "managerへの変更時に選択されていなければ削除されること" do
      # customerはis_owner: generalのまま、廃止済みの自己申告制イベント編集者機能や
      # 過去のデータ等でcommunity_aのレコードだけが残っている状態を再現する。
      CommunityEventEditor.create!(customer: customer, community: community_a)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_b.id] }
      }

      expect(customer.reload.edited_communities).to contain_exactly(community_b)
      expect(CommunityEventEditor.exists?(customer: customer, community: community_a)).to eq false
    end

    it "他ユーザーのCommunityEventEditorレコードには影響しないこと" do
      other_customer = FactoryBot.create(:customer, is_owner: :manager)
      CommunityEventEditor.create!(customer: other_customer, community: community_a)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_b.id] }
      }

      expect(other_customer.reload.edited_communities).to contain_exactly(community_a)
    end

    it "他コミュニティのCommunityEventEditorレコードには影響しないこと" do
      other_customer = FactoryBot.create(:customer, is_owner: :manager)
      CommunityEventEditor.create!(customer: other_customer, community: community_b)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_b.id] }
      }

      expect(CommunityEventEditor.where(community: community_b).map(&:customer)).to contain_exactly(customer, other_customer)
    end
  end

  describe "役職切り替え" do
    it "community_ownerからmanagerへ切り替えるとCommunityOwnerが解除されCommunityEventEditorへ切り替わること" do
      customer.update!(is_owner: :community_owner)
      CommunityOwner.create!(customer: customer, community: community_a)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_a.id] }
      }

      expect(customer.reload.owned_communities).to be_empty
      expect(customer.edited_communities).to contain_exactly(community_a)
    end

    it "managerからcommunity_ownerへ切り替えるとCommunityEventEditorが解除されCommunityOwnerへ切り替わること" do
      customer.update!(is_owner: :manager)
      CommunityEventEditor.create!(customer: customer, community: community_a)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "community_owner", owned_community_ids: [community_a.id] }
      }

      expect(customer.reload.edited_communities).to be_empty
      expect(customer.owned_communities).to contain_exactly(community_a)
    end

    it "managerからgeneralへ切り替えるとCommunityEventEditorが解除されること" do
      customer.update!(is_owner: :manager)
      CommunityEventEditor.create!(customer: customer, community: community_a)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "general", owned_community_ids: [""] }
      }

      expect(customer.reload.edited_communities).to be_empty
    end

    it "存在しないcommunity_idを送信しても500にならないこと" do
      expect do
        patch admin_customer_path(customer), params: {
          customer: { is_owner: "manager", owned_community_ids: ["999999999"] }
        }
      end.not_to raise_error

      expect(response).to redirect_to(admin_homes_top_path)
      expect(customer.reload.edited_communities).to be_empty
    end

    it "Community.owner_id本人をmanager担当として登録しないこと" do
      community_a.update!(owner_id: customer.id)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_a.id] }
      }

      expect(customer.reload.edited_communities).to be_empty
    end

    it "管理者をCommunityEventEditorへ登録せず、既存どおりcommunity_ownersへ保存されること" do
      patch admin_customer_path(customer), params: {
        customer: { is_owner: "admin", owned_community_ids: [community_a.id] }
      }

      expect(customer.reload.owned_communities).to contain_exactly(community_a)
      expect(customer.edited_communities).to be_empty
    end

    it "paramsに管理コミュニティが含まれない場合は既存の関連を変更しないこと" do
      customer.update!(is_owner: :manager)
      CommunityEventEditor.create!(customer: customer, community: community_a)

      patch admin_customer_path(customer), params: { customer: { name: customer.name } }

      expect(customer.reload.edited_communities).to contain_exactly(community_a)
    end

    it "他ユーザーの管理コミュニティ関連を変更しないこと" do
      other_customer = FactoryBot.create(:customer, is_owner: :community_owner)
      CommunityOwner.create!(customer: other_customer, community: community_a)

      patch admin_customer_path(customer), params: {
        customer: { is_owner: "manager", owned_community_ids: [community_b.id] }
      }

      expect(other_customer.reload.owned_communities).to contain_exactly(community_a)
    end
  end
end
