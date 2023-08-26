require 'rails_helper'

RSpec.describe "chat_messagesコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  let(:other_customer) { create(:customer) }
  let(:chat_room) { create(:chat_room) }
  let!(:chat_room_customer) { create(:chat_room_customer, customer: other_customer, chat_room: chat_room) }

  describe "ログイン済み" do
    context "createアクションのテスト" do
      before do
        sign_in customer
        get public_chat_room_path(chat_room)
        @chat_room = chat_room
      end
      it "メッセージ作成が成功する" do
        expect do
          post public_chat_messages_path, params: {
          chat_message: {
            content: "お元気ですか？",
            chat_room_id: 1,
            customer_id: 1,
          }
          }
        end.to change(ChatMessage, :count).by(1)
      end
    end
    context "community_createアクションのテスト" do
      before do
        sign_in customer
        @chat_room = chat_room
      end
      it "コミュニティへメッセージ作成が成功する" do
        expect do
          post community_create_public_chat_messages_path, params: {
          chat_message: {
            content: "お元気ですか？",
            chat_room_id: 1,
            customer_id: 1,
          }
          }
        end.to change(ChatMessage, :count).by(1)
      end
    end
    context "非ログイン" do
      it "リクエストは302 Foundとなること" do
        post "/public/chat_messages", params: {
          chat_message: {
            context: "お元気ですか？",
            chat_room_id: 1,
            customer_id: 1,
          }
        }
        expect(response).to have_http_status "302"
      end
      it "ログイン画面にリダイレクトされているか？" do
        post "/public/chat_messages", params: {
          chat_message: {
            context: "お元気ですか？",
            chat_room_id: 1,
            customer_id: 1,
          }
        }
        expect(response).to redirect_to "/customers/sign_in"
      end
    end
  end
end