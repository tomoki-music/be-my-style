require 'rails_helper'

RSpec.describe "chat_roomsコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "チャットルームが正しく表示される" do
      before do
        get public_chat_room_path(customer)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("チャットルームへようこそ!")
      end
    end
  end
  describe '非ログイン' do
    context "チャットルームへ遷移されない" do
      before do
        get public_chat_room_path(customer)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
  end
end
