require 'rails_helper'

RSpec.describe "Business::CommunityCustomers", type: :request do
  let(:owner) { create(:customer) }
  let(:community) { create(:community, owner: owner) }
  let(:applicant) { create(:customer) }
  let!(:permit) { create(:permit, community: community, customer: applicant) }

  before { sign_in owner }

  describe "POST /business/communities/:community_id/community_customers (create)" do
    it "有効ユーザーの参加を許可できること" do
      expect do
        post business_community_community_customers_path(community_id: community.id, customer_id: applicant.id)
      end.to change(CommunityCustomer, :count).by(1)
    end

    context "申請者が退会済み(is_deleted: true)の場合" do
      before { applicant.update!(is_deleted: true) }

      it "CommunityCustomerが作成されないこと" do
        expect do
          post business_community_community_customers_path(community_id: community.id, customer_id: applicant.id)
        end.not_to change(CommunityCustomer, :count)
      end

      it "500エラーにならず安全にリダイレクトされること" do
        post business_community_community_customers_path(community_id: community.id, customer_id: applicant.id)

        expect(response.status).to eq 302
      end
    end
  end
end
