require 'rails_helper'

RSpec.describe "Admin::Homes", type: :request do
  let(:admin) { FactoryBot.create(:admin) }

  before do
    # Admin::HomesControllerはApplicationController共通のauthenticate_customer!を
    # skipしていない既存の挙動のため、管理者ログインに加えてCustomerのログインも必要になる。
    sign_in FactoryBot.create(:customer)
    sign_in admin
  end

  def role_badge_texts(body, customer)
    row = Nokogiri::HTML(body).css("table tbody tr").find do |tr|
      tr.at_css("th")&.text&.strip == customer.id.to_s
    end
    row.css("td")[1].css(".badge").map { |badge| badge.text.strip }
  end

  describe "GET /admin/homes/top" do
    it "200を返すこと" do
      get admin_homes_top_path

      expect(response).to have_http_status(:ok)
    end

    it "Customer#admin?のCustomerに「管理者」が表示されること" do
      customer = FactoryBot.create(:customer, is_owner: :admin)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to include("管理者")
    end

    it "CommunityOwner経由だけの担当者に「オーナー（1）」が表示されること" do
      customer = FactoryBot.create(:customer)
      community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityOwner.create!(customer: customer, community: community)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to include("オーナー（1）")
    end

    it "Community#owner_id経由だけの担当者にも「オーナー（1）」が表示されること" do
      customer = FactoryBot.create(:customer)
      FactoryBot.create(:community, owner_id: customer.id)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to include("オーナー（1）")
    end

    it "同一Communityが両経路に存在しても「オーナー（1）」になること" do
      customer = FactoryBot.create(:customer)
      community = FactoryBot.create(:community, owner_id: customer.id)
      CommunityOwner.create!(customer: customer, community: community)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to include("オーナー（1）")
    end

    it "異なるCommunityを両経路で担当する場合、正しい合計件数になること" do
      customer = FactoryBot.create(:customer)
      direct_community = FactoryBot.create(:community, owner_id: customer.id)
      association_community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityOwner.create!(customer: customer, community: association_community)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to include("オーナー（2）")
      expect(direct_community).to be_present
    end

    it "CommunityEventEditorを1件持つ場合に「マネージャー（1）」が表示されること" do
      customer = FactoryBot.create(:customer)
      community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityEventEditor.create!(customer: customer, community: community)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to include("マネージャー（1）")
    end

    it "CommunityEventEditorが複数ある場合に件数が正しいこと" do
      customer = FactoryBot.create(:customer)
      community_a = FactoryBot.create(:community, owner_id: admin.id)
      community_b = FactoryBot.create(:community, owner_id: admin.id)
      CommunityEventEditor.create!(customer: customer, community: community_a)
      CommunityEventEditor.create!(customer: customer, community: community_b)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to include("マネージャー（2）")
    end

    it "管理者はBeMyStyleの最上位ロールのため、オーナー・マネージャーの実担当があっても「管理者」のみ表示されること" do
      customer = FactoryBot.create(:customer, is_owner: :admin)
      owned_community = FactoryBot.create(:community, owner_id: customer.id)
      edited_community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityEventEditor.create!(customer: customer, community: edited_community)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to eq(["管理者"])
      expect(owned_community).to be_present
    end

    it "管理者かつCommunityOwner関連ありでも「管理者」のみ表示されること" do
      customer = FactoryBot.create(:customer, is_owner: :admin)
      community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityOwner.create!(customer: customer, community: community)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to eq(["管理者"])
    end

    it "管理者かつCommunityEventEditor関連ありでも「管理者」のみ表示されること" do
      customer = FactoryBot.create(:customer, is_owner: :admin)
      community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityEventEditor.create!(customer: customer, community: community)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to eq(["管理者"])
    end

    it "管理者かつ両方の関連ありでも「オーナー」「マネージャー」のバッジが表示されないこと" do
      customer = FactoryBot.create(:customer, is_owner: :admin)
      owner_community = FactoryBot.create(:community, owner_id: admin.id)
      manager_community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityOwner.create!(customer: customer, community: owner_community)
      CommunityEventEditor.create!(customer: customer, community: manager_community)

      get admin_homes_top_path

      badges = role_badge_texts(response.body, customer)
      expect(badges.grep(/オーナー/)).to be_empty
      expect(badges.grep(/マネージャー/)).to be_empty
      expect(badges).to eq(["管理者"])
    end

    it "管理者ではない場合、オーナーとマネージャーを同時に持つと両方表示されること" do
      customer = FactoryBot.create(:customer)
      owner_community = FactoryBot.create(:community, owner_id: admin.id)
      manager_community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityOwner.create!(customer: customer, community: owner_community)
      CommunityEventEditor.create!(customer: customer, community: manager_community)

      get admin_homes_top_path

      badges = role_badge_texts(response.body, customer)
      expect(badges).to include("オーナー（1）", "マネージャー（1）")
    end

    it "enumがcommunity_ownerでも実担当がなければオーナーを表示しないこと" do
      customer = FactoryBot.create(:customer, is_owner: :community_owner)

      get admin_homes_top_path

      badges = role_badge_texts(response.body, customer)
      expect(badges.grep(/オーナー/)).to be_empty
      expect(badges).to include("一般会員")
    end

    it "enumがmanagerでも実担当がなければマネージャーを表示しないこと" do
      customer = FactoryBot.create(:customer, is_owner: :manager)

      get admin_homes_top_path

      badges = role_badge_texts(response.body, customer)
      expect(badges.grep(/マネージャー/)).to be_empty
      expect(badges).to include("一般会員")
    end

    it "enumがgeneralでも実担当があれば担当ロールを表示すること" do
      customer = FactoryBot.create(:customer, is_owner: :general)
      community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityOwner.create!(customer: customer, community: community)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to include("オーナー（1）")
    end

    it "どの権限もないCustomerに「一般会員」が表示されること" do
      customer = FactoryBot.create(:customer)

      get admin_homes_top_path

      expect(role_badge_texts(response.body, customer)).to eq(["一般会員"])
    end

    it "退会済みCustomerの既存表示とロール表示が共存すること" do
      customer = FactoryBot.create(:customer, is_deleted: true)
      community = FactoryBot.create(:community, owner_id: admin.id)
      CommunityOwner.create!(customer: customer, community: community)

      get admin_homes_top_path

      expect(response.body).to include("退会済み")
      expect(role_badge_texts(response.body, customer)).to include("オーナー（1）")
    end

    it "既存の絞り込み(member_type)が壊れていないこと" do
      customer = FactoryBot.create(:customer)
      customer.create_member_profile!(suggested_member_type: :growth)

      get admin_homes_top_path, params: { member_type: "growth" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(customer.name)
    end

    it "既存の詳細・承認・完全退会リンクが維持されること" do
      customer = FactoryBot.create(:customer)

      get admin_homes_top_path

      expect(response.body).to include(edit_admin_customer_path(customer.id))
      expect(response.body).to include(purge_path(customer_id: customer.id))
    end

    it "ロール表示に関するSQL数がCustomer数に比例して増えないこと" do
      FactoryBot.create_list(:customer, 3) do |customer|
        community = FactoryBot.create(:community, owner_id: admin.id)
        CommunityOwner.create!(customer: customer, community: community)
        CommunityEventEditor.create!(customer: customer, community: community)
      end

      queries = []
      callback = lambda do |*, payload|
        sql = payload[:sql]
        queries << sql if sql.match?(/community_owners|community_event_editors|FROM `communities`/) && !sql.match?(/SCHEMA/)
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get admin_homes_top_path
      end

      expect(queries.size).to be <= 3
    end
  end
end
