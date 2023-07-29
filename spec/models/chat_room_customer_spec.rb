require 'rails_helper'

RSpec.describe 'ChatRoomCustomerモデルのテスト', type: :model do
  describe 'アソシエーションのテスト' do
    context '「customer」「chat_room」「community」の中間テーブルとして' do
      it 'CustomersとN:1となっている' do
        expect(ChatRoomCustomer.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'chat_roomsとN:1となっている' do
        expect(ChatRoomCustomer.reflect_on_association(:chat_room).macro).to eq :belongs_to
      end
      it 'communitiesとN:1となっている' do
        expect(ChatRoomCustomer.reflect_on_association(:community).macro).to eq :belongs_to
      end
    end
  end
end