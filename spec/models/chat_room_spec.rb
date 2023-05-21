require 'rails_helper'

RSpec.describe 'ChatRoomモデルのテスト', type: :model do
  describe 'アソシエーションのテスト' do
    context 'customerモデルとの関係' do
      it 'customerとの中間テーブルと1:Nとなっている' do
        expect(ChatRoom.reflect_on_association(:chat_room_customers).macro).to eq :has_many
      end
      it 'customerと1:Nとなっている' do
        expect(ChatRoom.reflect_on_association(:customers).macro).to eq :has_many
      end
    end
    context 'チャットメッセージ機能について' do
      it 'chat_messageと1:Nとなっている' do
        expect(ChatRoom.reflect_on_association(:chat_messages).macro).to eq :has_many
      end
    end
  end
end