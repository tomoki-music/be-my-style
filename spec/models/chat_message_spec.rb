require 'rails_helper'

RSpec.describe 'ChatMessageモデルのテスト', type: :model do
  let(:customer) { FactoryBot.create(:customer) }
  let(:other_customer) { FactoryBot.create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let(:chat_message) { FactoryBot.create(:chat_message, customer: other_customer, chat_room: chat_room) }

  describe 'アソシエーションのテスト' do
    context 'チャットメッセージ機能において' do
      it 'CustomersとN:1となっている' do
        expect(ChatMessage.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'chat_roomsとN:1となっている' do
        expect(ChatMessage.reflect_on_association(:chat_room).macro).to eq :belongs_to
      end
      it 'communitiesとN:1となっている' do
        expect(ChatMessage.reflect_on_association(:community).macro).to eq :belongs_to
      end
    end
  end
  describe 'バリデーションのテスト' do
    context 'チャットメッセージ機能について' do
      it 'メッセージが入力されていると正しく送信できる' do
        chat_message.content = '良いお天気ですね！'
        expect(chat_message.valid?).to eq true
      end
      it 'メッセージが空欄だとエラーになる' do
        chat_message.content = ''
        expect(chat_message.valid?).to eq false
      end
    end
  end
end