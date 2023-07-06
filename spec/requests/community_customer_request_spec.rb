require 'rails_helper'

RSpec.describe "community_customersコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let!(:community) { create(:community) }
  let!(:permit) { create(:permit, customer_id: other_customer.id, community_id: community.id) }

  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "コミュニティ加入申請(create)が正しく許可されメンバーが登録される" do
      before do
        get public_community_path(community)
      end
      it "加入申請の許可が成功する" do
        expect do
          post public_community_community_customers_path(community, permit_id: permit.id)
        end.to change(CommunityCustomer, :count).by(1)
      end
    end
  end
  describe '非ログイン' do
    context "コミュニティ加入申請(create)の許可に失敗する" do
      before do
        get public_community_path(community)
      end
      it "加入申請の許可が失敗する" do
        post public_community_community_customers_path(community, permit_id: permit.id)
        expect(response.status).to eq 302
      end
    end
  end
end
