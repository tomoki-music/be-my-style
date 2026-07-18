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
    context "content_formatのテスト(要件11の後方互換性)" do
      before { sign_in customer }

      it "createアクションで新規投稿すると content_format が markdown で保存されること" do
        post public_chat_messages_path, params: {
          chat_message: { content: "お元気ですか？", chat_room_id: chat_room.id, customer_id: other_customer.id }
        }
        expect(ChatMessage.last.content_format).to eq "markdown"
      end
    end
    context "previewアクションのテスト" do
      before { sign_in customer }

      it "200 OKで、レンダリング済みHTMLをJSONで返すこと" do
        post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)["html"]).to include("<strong>bold</strong>")
      end

      it "DBには何も保存しないこと" do
        expect do
          post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json
        end.not_to change(ChatMessage, :count)
      end

      it "XSSを含む入力はサニタイズされたHTMLを返すこと" do
        post preview_public_chat_messages_path, params: { content: "<script>alert(1)</script>" }, as: :json
        expect(JSON.parse(response.body)["html"]).not_to include("<script")
      end

      it "空文字を渡しても500にならず、空のHTMLを返すこと" do
        post preview_public_chat_messages_path, params: { content: "" }, as: :json
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)["html"]).to eq ""
      end

      it "contentパラメータ自体が無くても500にならないこと" do
        post preview_public_chat_messages_path, params: {}, as: :json
        expect(response).to have_http_status(200)
      end

      it "極端に長い入力でも例外にならず、上限文字数までで処理されること" do
        huge_input = "a" * 100_000
        post preview_public_chat_messages_path, params: { content: huge_input }, as: :json
        expect(response).to have_http_status(200)
        html = JSON.parse(response.body)["html"]
        expect(html.length).to be <= Chat::MarkdownRenderer::MAX_LENGTH + 50 # HTMLタグ分の余裕
      end

      it "レスポンスのContent-TypeがJSONであること" do
        post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json
        expect(response.content_type).to include("application/json")
      end

      it "GETではアクセスできないこと(ルーティングエラー)" do
        expect do
          get preview_public_chat_messages_path
        end.to raise_error(ActionController::RoutingError)
      end

      it "レンダリング中に予期しない例外が発生してもスタックトレース等を漏らさず、汎用エラーメッセージを返すこと" do
        allow(Chat::MarkdownRenderer).to receive(:call).and_raise(StandardError, "internal boom")

        post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]).to eq "プレビューを生成できませんでした"
        expect(response.body).not_to include("internal boom")
        expect(response.body).not_to include("markdown_renderer.rb")
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

      it "previewアクションも302 Foundとなること" do
        post preview_public_chat_messages_path, params: { content: "**bold**" }, as: :json
        expect(response).to have_http_status "302"
      end
    end
  end
end