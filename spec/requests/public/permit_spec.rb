require 'rails_helper'

RSpec.describe "permitsコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let!(:community) { create(:community) }

  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "コミュニティ加入申請(create)が正しく処理され登録される" do
      before do
        get public_community_path(community)
      end
      it "加入申請の作成が成功する" do
        expect do
          post public_community_permits_path(community)
        end.to change(Permit, :count).by(1)
      end
    end
    context "コミュニティ加入申請が正しく削除(destroy)できる" do
      before do
        get public_community_path(community)
        post public_community_permits_path(community)
      end
      it '正しく削除できる' do
        expect do
          delete public_community_permits_path(community)
        end.to change(Permit, :count).by(-1)
      end
    end
  end
  describe '非ログイン' do
    context "コミュニティ加入申請(create)が登録されない" do
      before do
        get public_community_path(community)
      end
      it "加入申請の作成が失敗する" do
        post public_community_permits_path(community)
        expect(response.status).to eq 302
      end
    end
    context "コミュニティ加入申請が正しく削除(destroy)できる" do
      before do
        get public_community_path(community)
        post public_community_permits_path(community)
      end
      it '削除に失敗する' do
        delete public_community_permits_path(community)
        expect(response.status).to eq 302
      end
    end
  end
end
