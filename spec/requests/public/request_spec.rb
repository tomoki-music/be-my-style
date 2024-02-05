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
  end

  describe '非ログイン' do

  end
end
