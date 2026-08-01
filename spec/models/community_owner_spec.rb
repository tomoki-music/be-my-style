require 'rails_helper'

RSpec.describe CommunityOwner, type: :model do
  describe 'アソシエーションのテスト' do
    context '親モデルとの関係' do
      it 'customerとN:1となっている' do
        expect(CommunityOwner.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'communityとN:1となっている' do
        expect(CommunityOwner.reflect_on_association(:community).macro).to eq :belongs_to
      end
    end
  end

  describe 'バリデーションのテスト' do
    let(:customer) { FactoryBot.create(:customer) }
    let(:community) { FactoryBot.create(:community) }

    it '同一customer・community組み合わせでは一意であること' do
      CommunityOwner.create!(customer: customer, community: community)
      duplicate = CommunityOwner.new(customer: customer, community: community)

      expect(duplicate.valid?).to eq false
    end

    it '異なるcommunityであれば同一customerで複数登録できること' do
      other_community = FactoryBot.create(:community)
      CommunityOwner.create!(customer: customer, community: community)
      another = CommunityOwner.new(customer: customer, community: other_community)

      expect(another.valid?).to eq true
    end

    it '異なるcustomerであれば同一communityで複数登録できること' do
      other_customer = FactoryBot.create(:customer)
      CommunityOwner.create!(customer: customer, community: community)
      another = CommunityOwner.new(customer: other_customer, community: community)

      expect(another.valid?).to eq true
    end

    it 'DBの一意インデックスにより、validationを迂回しても重複作成できないこと' do
      CommunityOwner.create!(customer: customer, community: community)
      duplicate = CommunityOwner.new(customer: customer, community: community)

      expect { duplicate.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
