require 'rails_helper'

RSpec.describe Admin::CustomersHelper, type: :helper do
  describe "#domain_badges" do
    it "singingユーザーに歌唱・演奏診断バッヂを表示すること" do
      customer = instance_double(
        Customer,
        music_user?: false,
        business_user?: false,
        learning_user?: false,
        singing_user?: true
      )

      html = helper.domain_badges(customer)

      expect(html).to include("歌唱・演奏診断")
      expect(html).to include("bi-mic")
    end

    it "複数ドメインを持つユーザーの既存バッヂも維持すること" do
      customer = instance_double(
        Customer,
        music_user?: true,
        business_user?: true,
        learning_user?: true,
        singing_user?: true
      )

      html = helper.domain_badges(customer)

      expect(html).to include("音楽")
      expect(html).to include("ビジネス")
      expect(html).to include("学習")
      expect(html).to include("歌唱・演奏診断")
    end
  end

  describe "#admin_customer_role_items / #admin_customer_role_badges" do
    def role_customer(admin: false, community_owners: [], community_event_editors: [])
      instance_double(
        Customer,
        admin?: admin,
        community_owners: community_owners,
        community_event_editors: community_event_editors
      )
    end

    it "管理者はkey: :admin, count: nilで返ること" do
      customer = role_customer(admin: true)

      items = helper.admin_customer_role_items(customer)

      expect(items).to include({ key: :admin, count: nil })
    end

    it "CommunityOwner経由の担当件数がカウントされること" do
      community_owners = [
        instance_double(CommunityOwner, community_id: 1),
        instance_double(CommunityOwner, community_id: 2)
      ]
      customer = role_customer(community_owners: community_owners)

      items = helper.admin_customer_role_items(customer)

      expect(items).to include({ key: :community_owner, count: 2 })
    end

    it "Community#owner_id経由(直接担当)の件数もカウントされること" do
      customer = role_customer
      direct_owned_communities = [instance_double(Community, id: 10)]

      items = helper.admin_customer_role_items(customer, direct_owned_communities)

      expect(items).to include({ key: :community_owner, count: 1 })
    end

    it "CommunityOwnerと直接担当が同一コミュニティの場合、重複排除されること" do
      community_owners = [instance_double(CommunityOwner, community_id: 10)]
      direct_owned_communities = [instance_double(Community, id: 10)]
      customer = role_customer(community_owners: community_owners)

      items = helper.admin_customer_role_items(customer, direct_owned_communities)

      expect(items).to include({ key: :community_owner, count: 1 })
    end

    it "マネージャーの担当件数がカウントされること" do
      community_event_editors = [
        instance_double(CommunityEventEditor, community_id: 1),
        instance_double(CommunityEventEditor, community_id: 2),
        instance_double(CommunityEventEditor, community_id: 3)
      ]
      customer = role_customer(community_event_editors: community_event_editors)

      items = helper.admin_customer_role_items(customer)

      expect(items).to include({ key: :manager, count: 3 })
    end

    it "管理者かつオーナー・マネージャーの実担当がある場合でも、オーナー・マネージャーを併記せず管理者のみ返ること" do
      community_owners = [instance_double(CommunityOwner, community_id: 1)]
      community_event_editors = [instance_double(CommunityEventEditor, community_id: 2)]
      customer = role_customer(admin: true, community_owners: community_owners, community_event_editors: community_event_editors)

      items = helper.admin_customer_role_items(customer)

      expect(items).to eq([{ key: :admin, count: nil }])
    end

    it "管理者かつCommunityOwner関連ありでも「管理者」のみ返ること" do
      community_owners = [instance_double(CommunityOwner, community_id: 1)]
      customer = role_customer(admin: true, community_owners: community_owners)

      items = helper.admin_customer_role_items(customer)

      expect(items).to eq([{ key: :admin, count: nil }])
    end

    it "管理者かつCommunityEventEditor関連ありでも「管理者」のみ返ること" do
      community_event_editors = [instance_double(CommunityEventEditor, community_id: 1)]
      customer = role_customer(admin: true, community_event_editors: community_event_editors)

      items = helper.admin_customer_role_items(customer)

      expect(items).to eq([{ key: :admin, count: nil }])
    end

    it "管理者かつCommunity#owner_id経由の直接担当ありでも「管理者」のみ返ること" do
      customer = role_customer(admin: true)
      direct_owned_communities = [instance_double(Community, id: 1)]

      items = helper.admin_customer_role_items(customer, direct_owned_communities)

      expect(items).to eq([{ key: :admin, count: nil }])
    end

    it "管理者の場合、「オーナー」「マネージャー」のバッジが表示されないこと" do
      community_owners = [instance_double(CommunityOwner, community_id: 1)]
      community_event_editors = [instance_double(CommunityEventEditor, community_id: 2)]
      customer = role_customer(admin: true, community_owners: community_owners, community_event_editors: community_event_editors)

      html = helper.admin_customer_role_badges(customer)

      expect(html).not_to include(I18n.t("admin.customers.roles.community_owner"))
      expect(html).not_to include(I18n.t("admin.customers.roles.manager"))
      expect(html).to include(I18n.t("admin.customers.roles.admin"))
    end

    it "オーナーとマネージャーを同時に持つ(管理者ではない)場合は両方返ること" do
      community_owners = [instance_double(CommunityOwner, community_id: 1)]
      community_event_editors = [instance_double(CommunityEventEditor, community_id: 2)]
      customer = role_customer(community_owners: community_owners, community_event_editors: community_event_editors)

      items = helper.admin_customer_role_items(customer)

      expect(items).to contain_exactly(
        { key: :community_owner, count: 1 },
        { key: :manager, count: 1 }
      )
    end

    it "何も持たない場合は一般会員のみ返ること" do
      customer = role_customer

      items = helper.admin_customer_role_items(customer)

      expect(items).to eq([{ key: :general, count: nil }])
    end

    it "localeのラベルを使用してバッジHTMLを生成すること" do
      customer = role_customer(admin: true)

      html = helper.admin_customer_role_badges(customer)

      expect(html).to include(I18n.t("admin.customers.roles.admin"))
    end

    it "管理者にはbadge-dangerを使用すること" do
      customer = role_customer(admin: true)

      html = helper.admin_customer_role_badges(customer)

      expect(html).to include("badge-danger")
    end

    it "オーナー・マネージャーにはそれぞれbadge-warning/badge-infoを使用すること" do
      community_owners = [instance_double(CommunityOwner, community_id: 1)]
      community_event_editors = [instance_double(CommunityEventEditor, community_id: 2)]
      customer = role_customer(community_owners: community_owners, community_event_editors: community_event_editors)

      html = helper.admin_customer_role_badges(customer)

      expect(html).to include("badge-warning")
      expect(html).to include("badge-info")
    end

    it "何も持たない場合はbadge-secondaryで一般会員を表示すること" do
      customer = role_customer

      html = helper.admin_customer_role_badges(customer)

      expect(html).to include("badge-secondary")
      expect(html).to include("一般会員")
    end

    it "instance_doubleに対して動作し、Helper内でDB Queryを発行する前提を持たないこと" do
      # community_owners/community_event_editorsはコントローラーで事前ロード済みの配列を想定しており、
      # instance_doubleでも(=ActiveRecordのクエリメソッドを呼ばずに).mapのみで動作することを保証する。
      customer = role_customer(community_owners: [instance_double(CommunityOwner, community_id: 1)])

      expect { helper.admin_customer_role_items(customer) }.not_to raise_error
    end
  end
end
