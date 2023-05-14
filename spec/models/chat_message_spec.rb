require 'rails_helper'

RSpec.describe 'ChatMessageモデルのテスト', type: :model do
  let(:customer) { FactoryBot.create(:customer) }
  let(:other_customer) { FactoryBot.create(:customer) }

  describe 'アソシエーションのテスト' do
    context 'チャットメッセージ機能において' do
      it 'CustomersとN:1となっている' do
        expect(ChatMessage.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'chat_roomsとN:1となっている' do
        expect(ChatMessage.reflect_on_association(:chat_room).macro).to eq :belongs_to
      end
    end
  end
end