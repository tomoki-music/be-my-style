require 'rails_helper'

RSpec.describe JoinPartCustomer, type: :model do
  describe 'アソシエーションのテスト' do
    context 'Customerモデルとの関係' do
      it 'customerとN:1となっている' do
        expect(JoinPartCustomer.reflect_on_association(:customer).macro).to eq :belongs_to
      end
    end
    context 'JoinPartモデルとの関係' do
      it 'join_partとN:1となっている' do
        expect(JoinPartCustomer.reflect_on_association(:join_part).macro).to eq :belongs_to
      end
    end
  end
end
