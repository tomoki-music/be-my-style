require 'rails_helper'

RSpec.describe "chat_roomsコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let!(:chat_room_customer) { create(:chat_room_customer, customer: other_customer, chat_room: chat_room) }
  let(:community) { create(:community) }

  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "チャットルームが正しく作成(create)される" do
      it 'チャットルームが１つ作成されること' do
        expect do
          post public_chat_rooms_path(customer_id: other_customer.id)
        end.to change(ChatRoom, :count).by(1)
      end
    end
    context "チャットルームが正しく表示(show)される" do
      before do
        get community_show_public_chat_rooms_path(chat_room)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("チャットルームへようこそ!")
      end
    end
    context "コミュニティチャットルームが正しく作成(create)される" do
      it 'コミュニティチャットルームが１つ作成されること' do
        expect do
          post community_create_public_chat_rooms_path(community_id: community.id)
        end.to change(ChatRoom, :count).by(1)
      end
    end
    context "コミュニティのチャットルームが正しく表示(show)される" do
      before do
        get community_show_public_chat_rooms_path(chat_room)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("コミュニティチャットルームへようこそ!")
      end
    end
  end
  describe '非ログイン' do
    context "チャットルームが正しく作成(create)されない" do
      before do
        post public_chat_rooms_path(customer_id: other_customer.id)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "チャットルームへ遷移(show)されない" do
      before do
        get public_chat_room_path(chat_room)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
  end
end
