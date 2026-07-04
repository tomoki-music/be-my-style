require 'rails_helper'

RSpec.describe "コミュニティチャットの閲覧・投稿権限のテスト", type: :request do
  let!(:customer) { create(:customer) }
  let!(:owner) { create(:customer) }
  let(:community) { create(:community, owner_id: owner.id) }
  let(:chat_room) { create(:chat_room) }
  let!(:owner_chat_room_customer) { create(:chat_room_customer, customer: owner, chat_room: chat_room, community: community) }
  let!(:member_chat_room_customer) { create(:chat_room_customer, customer: customer, chat_room: chat_room, community: community) }

  describe 'ログイン済み（コミュニティ参加済み）' do
    before { sign_in customer }

    context 'Freeプランの場合' do
      it 'コミュニティ詳細ページにチャットルームへのリンクが表示されること' do
        get public_community_path(community)
        expect(response.body).to include('コミュニティのチャットルームへ')
      end

      it 'コミュニティチャットルームへ入室できること(community_create)' do
        post community_create_public_chat_rooms_path(community_id: community.id)
        expect(response).to redirect_to(community_show_public_chat_rooms_path(chat_room))
      end

      it 'コミュニティチャットルームを閲覧できること(community_show)' do
        get community_show_public_chat_rooms_path(chat_room)
        expect(response.status).to eq 200
        expect(response.body).to include('コミュニティチャットルームへようこそ!')
      end

      it '通常の投稿フォームが表示されること' do
        get community_show_public_chat_rooms_path(chat_room)
        expect(response.body).to include('メッセージを送信')
      end

      it 'コミュニティチャットへの投稿ができること(community_create)' do
        expect do
          post community_create_public_chat_messages_path, params: {
            chat_message: { content: "お元気ですか？", chat_room_id: chat_room.id }
          }
        end.to change(ChatMessage, :count).by(1)
      end
    end

    context 'Lightプラン以上の場合' do
      before { customer.create_subscription!(status: "active", plan: "light") }

      it 'これまで通りコミュニティチャットルームを閲覧できること' do
        get community_show_public_chat_rooms_path(chat_room)
        expect(response.status).to eq 200
      end

      it 'これまで通りコミュニティチャットへ投稿できること(community_create)' do
        expect do
          post community_create_public_chat_messages_path, params: {
            chat_message: { content: "お元気ですか？", chat_room_id: chat_room.id }
          }
        end.to change(ChatMessage, :count).by(1)
      end
    end
  end

  describe '未ログイン' do
    it 'コミュニティチャットルームの閲覧はログイン画面へリダイレクトされること' do
      get community_show_public_chat_rooms_path(chat_room)
      expect(response).to redirect_to(new_customer_session_path)
    end
  end

  describe '他の有料機能フラグへの影響がないこと' do
    before { sign_in customer }

    it 'イベント作成はCore未満のFreeユーザーには従来通り開放されないこと' do
      expect(customer.has_feature?(:music_event_create)).to eq false
    end

    it 'コミュニティ作成はFreeユーザーには従来通り開放されないこと' do
      expect(customer.has_feature?(:music_community_create)).to eq false
    end
  end
end
