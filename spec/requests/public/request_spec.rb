require 'rails_helper'

RSpec.describe "Public::Requests", type: :request do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:join_part) { FactoryBot.create(:join_part, song: song) }
  let(:song) { FactoryBot.create(:song, :song_with_parts, event: event) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:request) { FactoryBot.create(:request, customer_id: other_customer.id, event_id: event.id) }

  describe 'ログイン済み' do
    before do
      sign_in customer
      get public_event_path(event)
    end
    context "リクエスト(create)が正しく処理され登録される" do
      it "リクエストの作成が成功する" do
        expect do
          post public_event_requests_path(event_id: event.id), params: {
            request: {
              request: "オリジナル曲を１曲お願いします！",
            }
          }
        end.to change(Request, :count).by(1)
      end
    end
    context "リクエストを正しく削除(destroy)できる" do
      before do
        request
      end
      it '正しく削除できる（リクエスト本人である場合）' do
        expect do
          delete public_event_request_path(event_id: event.id, id: request.id)
        end.to change(Request, :count).by(-1)
      end
    end
    context "コメントを正しく削除(destroy)できない" do
      before do
        sign_in other_customer
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        delete public_event_request_path(event_id: event.id, id: request.id)
        expect(response.status).to eq 302
      end
    end

    context "みんなのリクエストのYouTubeカード表示" do
      it "YouTube URLを含むリクエストを投稿すると、イベント画面にサムネイルカードが表示されること" do
        post public_event_requests_path(event_id: event.id), params: {
          request: {
            request: "この曲でお願いします！ https://www.youtube.com/watch?v=abcdefghijk"
          }
        }, xhr: true

        get public_event_path(event)

        expect(response.status).to eq 200
        expect(response.body).to include("img.youtube.com/vi/abcdefghijk/hqdefault.jpg")
      end

      it "URLを含まないリクエストではカードが表示されないこと(既存表示を維持)" do
        post public_event_requests_path(event_id: event.id), params: {
          request: {
            request: "オリジナル曲を１曲お願いします！"
          }
        }, xhr: true

        get public_event_path(event)

        expect(response.status).to eq 200
        expect(response.body).not_to include("event-song-youtube-card")
      end

      it "不正なURLを含むリクエストでも500エラーにならず、リンクとして描画されないこと" do
        post public_event_requests_path(event_id: event.id), params: {
          request: {
            request: "javascript:alert(1)"
          }
        }, xhr: true

        get public_event_path(event)

        expect(response.status).to eq 200
        expect(response.body).not_to include('href="javascript:alert(1)"')
        expect(response.body).not_to include("event-song-youtube-card")
      end
    end
  end

  describe '非ログイン' do

  end
end
