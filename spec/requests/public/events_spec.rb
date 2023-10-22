require 'rails_helper'

RSpec.describe "Public::Events", type: :request do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }

  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "event一覧ページ(index)が正しく表示される" do
      before do
        get public_events_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "event詳細ページ(show)が正しく表示される" do
      before do
        get public_event_path(event)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "event新規作成ページ(new)が正しく表示される" do
      before do
        get new_public_event_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "event新規作成(create)が正しく処理され登録される" do
      it "eventの作成が成功する" do
        expect do
          event
        end.to change(Event, :count).by(1)
      end
    end
    context "event編集ページ(edit)が正しく表示される" do
      it 'リクエストは200 OKとなること（投稿者本人である場合）' do
        get edit_public_event_path(event)
        expect(response.status).to eq 200
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        sign_in other_customer
        get edit_public_event_path(event)
        expect(response.status).to eq 302
      end
    end
    context "event編集(update)が正しく処理され登録される" do
      it '記事を編集できること(投稿者本人の場合)' do
        put public_event_path(event), params: {
          event: {
            customer_id: customer.id,
            community_id: community.id,
            event_name: "今回限定のセッション！",
            event_date: DateTime.now,
            entrance_fee: 1500,
            address: "埼玉県川口市",
            introduction: "今回限定のセッション開催です！",
          }
        }
        expect(event.reload.event_name).to eq '今回限定のセッション！'
        expect(event.reload.introduction).to eq '今回限定のセッション開催です！'
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        sign_in other_customer
        put public_event_path(event), params: {
          event: {
            event_name: "今回限定のセッション！",
            event_date: DateTime.now,
            entrance_fee: 1500,
            address: "埼玉県川口市",
            introduction: "今回限定のセッション開催です！",
          }
        }
        expect(response.status).to eq 302
      end
    end
    context "eventページを正しく削除(destroy)できる" do
      it '正しく削除できる（投稿者本人である場合）' do
        event
        expect do
          delete public_event_path(event)
        end.to change(Event, :count).by(-1)
      end
      it 'リクエストは302 Foundとなること（投稿者本人でない場合）' do
        sign_in other_customer
        delete public_event_path(event)
        expect(response.status).to eq 302
      end
    end
  end

  describe '非ログイン' do
    context "events一覧ページ(index)へ遷移されない" do
      before do
        get public_events_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "event詳細ページ(show)へ遷移されない" do
      before do
        get public_event_path(event)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "event新規作成ページ(new)へ遷移されない" do
      before do
        get new_public_event_path
      end
      it 'リクエストは302 OKとなること' do
        expect(response.status).to eq 302
      end
    end
    context "event新規作成(create)が正しく処理されない" do
      it "eventの作成に失敗する" do
        post public_events_path, params: {
          event: {
            customer_id: customer.id,
            community_id: community.id,
            event_name: "セッション開催！",
            event_date: DateTime.now,
            entrance_fee: 1500,
            address: "埼玉県川口市",
            introduction: "邦楽と洋楽のコピーセッション開催です！",
          }
        }
        expect(response.status).to eq 302
      end
    end
    context "event編集ページ(edit)が正しく表示されない" do
      it 'リクエストは302 となること' do
        get edit_public_event_path(event)
        expect(response.status).to eq 302
      end
    end
    context "event編集(update)が正しく処理され登録されない" do
      it 'リクエストは302 Foundとなること' do
        put public_event_path(event), params: {
          event: {
            event_name: "今回限定のセッション！",
            event_date: DateTime.now,
            entrance_fee: 1500,
            address: "埼玉県川口市",
            introduction: "今回限定のセッション開催です！",
          }
        }
        expect(response.status).to eq 302
      end
    end
    context "eventページを正しく削除(destroy)できない" do
      it 'リクエストは302 Foundとなること' do
        delete public_event_path(event)
        expect(response.status).to eq 302
      end
    end
  end
end
