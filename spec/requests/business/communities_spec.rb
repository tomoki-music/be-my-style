require 'rails_helper'

RSpec.describe "Business::Communities", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer) }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:customer) { create(:customer) }

  before do
    CommunityCustomer.find_or_create_by!(customer: owner, community: community)
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
    sign_in customer
  end

  describe "GET /business/communities/:id (show) の退会済みメンバー表示" do
    let(:withdrawn_member) { create(:customer, name: "退会済み次郎", is_deleted: true) }

    before do
      CommunityCustomer.find_or_create_by!(customer: withdrawn_member, community: community)
    end

    it '退会済みメンバーがメンバー一覧に表示されないこと' do
      get business_community_path(community)

      expect(response.body).to include(customer.name)
      expect(response.body).not_to include(withdrawn_member.name)
    end

    it '参加人数から退会済みメンバーが除かれること' do
      get business_community_path(community)

      expect(response.body).to include("#{community.active_customers.count}人")
      expect(community.customers.count).to eq(community.active_customers.count + 1)
    end

    it '退会済みメンバーのCommunityCustomerレコード自体は削除されないこと' do
      get business_community_path(community)

      expect(CommunityCustomer.exists?(community: community, customer: withdrawn_member)).to eq true
    end
  end

  describe "GET /business/communities/:id (show) の退会済みオーナー表示" do
    before { owner.update!(is_deleted: true) }

    it 'オーナー名・プロフィールリンク・役職バッジを表示しないこと' do
      get business_community_path(community)

      expect(response.body).to include("退会済みユーザー")
      expect(response.body).not_to include(owner.name)
      expect(response.body).not_to include(%(href="#{business_customer_path(owner)}"))
    end
  end

  describe "GET /business/communities/:id/permits (承認待ち一覧)" do
    let(:applicant) { create(:customer, name: "申請太郎") }
    let(:withdrawn_applicant) { create(:customer, name: "退会済み申請花子", is_deleted: true) }
    let!(:active_permit) { create(:permit, community: community, customer: applicant) }
    let!(:withdrawn_permit) { create(:permit, community: community, customer: withdrawn_applicant) }

    before { sign_in owner }

    it '退会済み申請者が一覧に表示されないこと' do
      get business_permits_path(community)

      expect(response.body).to include("申請太郎")
      expect(response.body).not_to include("退会済み申請花子")
    end
  end
end
