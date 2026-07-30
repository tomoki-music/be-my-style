require 'rails_helper'

RSpec.describe 'CommunityEventEditor中間モデルのテスト', type: :model do
  describe 'アソシエーションのテスト' do
    context '親モデルとの関係' do
      it 'customerとN:1となっている' do
        expect(CommunityEventEditor.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'communityとN:1となっている' do
        expect(CommunityEventEditor.reflect_on_association(:community).macro).to eq :belongs_to
      end
    end
  end

  describe 'バリデーションのテスト' do
    let(:customer) { FactoryBot.create(:customer) }
    let(:community) { FactoryBot.create(:community) }

    it '同一customer・community組み合わせでは一意であること' do
      CommunityEventEditor.create!(customer: customer, community: community)
      duplicate = CommunityEventEditor.new(customer: customer, community: community)

      expect(duplicate.valid?).to eq false
    end

    it '異なるcommunityであれば同一customerで複数登録できること' do
      other_community = FactoryBot.create(:community)
      CommunityEventEditor.create!(customer: customer, community: community)
      another = CommunityEventEditor.new(customer: customer, community: other_community)

      expect(another.valid?).to eq true
    end
  end
end
