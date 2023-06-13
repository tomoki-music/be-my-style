require 'rails_helper'

RSpec.describe 'Communityモデルのテスト', type: :model do
  let(:community) { FactoryBot.create(:community) }

  describe 'バリデーションのテスト' do
    context 'nameカラムが不正' do
      it '空欄でないこと' do
        community.name = ''
        expect(community.valid?).to eq false
      end
    end
    context 'introductionカラムが不正' do
      it '空欄でないこと' do
        community.introduction = ''
        expect(community.valid?).to eq false
      end
    end
  end
  describe 'アソシエーションのテスト' do
    context 'Customerモデルとの関係' do
      it 'customersと1:Nとなっている' do
        expect(Community.reflect_on_association(:customers).macro).to eq :has_many
      end
      it '中間テーブルcommunity_customersと1:Nとなっている' do
        expect(Community.reflect_on_association(:community_customers).macro).to eq :has_many
      end
    end
  end
end
