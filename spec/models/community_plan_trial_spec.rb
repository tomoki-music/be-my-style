require "rails_helper"

# 「有料プラン制限を解除する（無料お試し）」のプラン判定。
RSpec.describe "Community の有料プラン制限解除", type: :model do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:other_community) { create(:community, owner: owner, domain: business_domain) }
  let(:music_community) { create(:community, owner: owner, plan_restrictions_waived: true) }
  let(:free_customer) { create(:customer, domain_name: "business") }

  describe "Community#plan_restrictions_waived_for?" do
    it "OFF のときは解除しない" do
      expect(community.plan_restrictions_waived_for?(:business_project_create)).to eq false
    end

    it "ON の Business コミュニティでは対象機能を解除する" do
      community.update!(plan_restrictions_waived: true)

      expect(community.plan_restrictions_waived_for?(:business_project_create)).to eq true
      expect(community.plan_restrictions_waived_for?("business_community_post_create")).to eq true
    end

    it "コミュニティ外へ及ぶ機能(コミュニティ作成・ビジネス投稿)は解除しない" do
      community.update!(plan_restrictions_waived: true)

      expect(community.plan_restrictions_waived_for?(:business_community_create)).to eq false
      expect(community.plan_restrictions_waived_for?(:business_post_create)).to eq false
    end

    it "Business 以外のドメインではフラグが立っていても解除しない" do
      expect(music_community.plan_restrictions_waived_for?(:business_project_create)).to eq false
    end
  end

  describe "Customer#has_feature?" do
    before { community.update!(plan_restrictions_waived: true) }

    it "ON のコミュニティを渡したときだけ Free でも有料機能が使える" do
      expect(free_customer.has_feature?(:business_project_create, community: community)).to eq true
      expect(free_customer.has_feature?(:business_project_create, community: other_community)).to eq false
      expect(free_customer.has_feature?(:business_project_create)).to eq false
    end

    it "通常利用(コミュニティ指定なし)の判定は変わらない" do
      # ビジネス投稿はお試し設定と無関係に free で利用できる。
      expect(free_customer.has_feature?(:business_post_create)).to eq true
      expect(free_customer.has_feature?(:business_community_create)).to eq false
      expect(free_customer.has_feature?(:music_event_create)).to eq false
    end
  end

  describe "Customer#business_community_post_create(Free 化)" do
    it "お試し OFF でも Free プランで利用できる" do
      expect(free_customer.has_feature?(:business_community_post_create)).to eq true
    end
  end

  describe "Customer#business_community_participant?" do
    before { CommunityCustomer.create!(community: community, customer: free_customer) }

    it "参加中の Business コミュニティでのみ true" do
      expect(free_customer.business_community_participant?(community)).to eq true
      expect(free_customer.business_community_participant?(other_community)).to eq false
    end

    it "Business 以外のコミュニティでは false" do
      CommunityCustomer.create!(community: music_community, customer: free_customer)

      expect(free_customer.business_community_participant?(music_community)).to eq false
    end

    it "管理者(オーナー)は参加レコードが無くても true" do
      expect(owner.business_community_participant?(other_community)).to eq true
    end
  end
end
