require 'rails_helper'

RSpec.describe "chat_roomsコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:third_customer) { create(:customer) }
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
        # showはDM参加者のみ閲覧できるため、customer自身もこのchat_roomの参加者として登録する
        # (トップレベルのlet!はother_customerしか登録していない)。
        # また、このコンテキストは通常のDM show(public_chat_room_path)を検証する意図であり、
        # 元々community_show_public_chat_rooms_pathを呼んでいたのは経路違いの誤りだったため修正する。
        create(:chat_room_customer, chat_room: chat_room, customer: customer)
        get public_chat_room_path(chat_room, customer_id: other_customer.id)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("チャットルームへようこそ!")
      end
    end
    context "後方互換性(要件11)のテスト" do
      before do
        create(:chat_room_customer, chat_room: chat_room, customer: customer)
      end

      it "content_format が plain(Markdown対応以前)の既存メッセージは記号がそのままプレーン表示されること" do
        create(:chat_message, customer: other_customer, chat_room: chat_room, content: "*これは強調ではない*")
        get public_chat_room_path(chat_room, customer_id: other_customer.id)
        expect(response.body).to include("*これは強調ではない*")
        expect(response.body).not_to include("<em>これは強調ではない</em>")
      end

      it "content_format が markdown の新規メッセージはHTMLに変換されて表示されること" do
        create(:chat_message, :markdown, customer: other_customer, chat_room: chat_room, content: "**これは強調**")
        get public_chat_room_path(chat_room, customer_id: other_customer.id)
        expect(response.body).to include("<strong>これは強調</strong>")
      end
    end
    context "コミュニティチャットルームが正しく作成(create)される" do
      before { CommunityCustomer.find_or_create_by!(customer: customer, community: community) }

      it 'コミュニティチャットルームが１つ作成されること' do
        expect do
          post community_create_public_chat_rooms_path(community_id: community.id)
        end.to change(ChatRoom, :count).by(1)
      end
    end
    context "同じコミュニティメンバーでなければチャットルームは作成(community_create)されない" do
      before do
        sign_in third_customer
      end
      it 'チャットルームに入れずページリダイレクトされること' do
        post community_create_public_chat_rooms_path(community_id: community.id)
        expect(response.status).to eq 302
      end
    end
    context "コミュニティのチャットルームが正しく表示(show)される" do
      let(:community_chat_room) { create(:chat_room) }

      before do
        # community_showはコミュニティメンバーのみ閲覧できるため、customerをこの
        # community_chat_roomのメンバー(ChatRoomCustomer+CommunityCustomer)として登録する。
        # トップレベルのchat_room(DM用、community: nil)とは別のコミュニティ専用chat_roomを使う。
        create(:chat_room_customer, chat_room: community_chat_room, customer: customer, community: community)
        CommunityCustomer.find_or_create_by!(customer: customer, community: community)
        get community_show_public_chat_rooms_path(community_chat_room)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("コミュニティチャットルームへようこそ!")
      end
    end

    context "非参加者は他人のDMチャットルームを一覧閲覧できないこと" do
      it "参加していないchat_roomのIDを直接指定しても404となり、内容が漏れないこと" do
        get public_chat_room_path(chat_room, customer_id: other_customer.id)
        expect(response).to have_http_status(:not_found)
        expect(response.body).not_to include("チャットルームへようこそ!")
      end
    end

    context "非参加者は未参加コミュニティのチャットルームを一覧閲覧できないこと" do
      let(:community_chat_room) { create(:chat_room) }
      let(:member) { create(:customer) }

      before do
        create(:chat_room_customer, chat_room: community_chat_room, customer: member, community: community)
        CommunityCustomer.find_or_create_by!(customer: member, community: community)
      end

      it "参加していないコミュニティのchat_room IDを直接指定しても404となり、内容が漏れないこと" do
        get community_show_public_chat_rooms_path(community_chat_room)
        expect(response).to have_http_status(:not_found)
        expect(response.body).not_to include("コミュニティチャットルームへようこそ!")
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
