require 'rails_helper'

RSpec.describe 'CommunityCustomer中間モデルのテスト', type: :model do
  describe 'アソシエーションのテスト' do
    context '親モデルとの関係' do
      it 'customerとN:1となっている' do
        expect(CommunityCustomer.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'communityとN:1となっている' do
        expect(CommunityCustomer.reflect_on_association(:community).macro).to eq :belongs_to
      end
    end
  end
end
