require 'rails_helper'

RSpec.describe 'Permitモデルのテスト', type: :model do

  describe 'バリデーションのテスト' do

  end
  describe 'アソシエーションのテスト' do
    context '中間テーブルとしてのアソシエーションテスト' do
      it 'customersとN:1となっている' do
        expect(Permit.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'communitiesとN:1となっている' do
        expect(Permit.reflect_on_association(:community).macro).to eq :belongs_to
      end
    end
  end
end
