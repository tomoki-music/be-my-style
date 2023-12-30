require 'rails_helper'

RSpec.describe "Admin::Events", type: :request do
  let(:admin) { FactoryBot.create(:admin) }
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }

  describe 'ログイン済み' do
    before do
      sign_in admin
    end
    context "event一覧ページ(index)が正しく表示される" do
      before do
        get admin_events_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "event詳細ページ(show)が正しく表示される" do
      before do
        get admin_event_path(event)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
    context "eventページを正しく削除(destroy)できる" do
      it '正しく削除できる' do
        event
        expect do
          delete admin_event_path(event)
        end.to change(Event, :count).by(-1)
      end
    end
    # context "event参加メンバーを正しく削除(delete)できる" do
    #   it '正しくメンバー削除できる' do
    #     event
    #     public_event_join_path(event)
    #     expect do
    #       delete admin_event_delete_path(event, customer_id: customer, join_part_id: join_part)
    #     end.to change(, :count).by(-1)
    #   end
    # end
  end

  describe '非ログイン' do
    context "events一覧ページ(index)へ遷移されない" do
      before do
        get admin_events_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "event詳細ページ(show)へ遷移されない" do
      before do
        get admin_event_path(event)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "eventページを正しく削除(destroy)できない" do
      it 'リクエストは302 Foundとなること' do
        delete admin_event_path(event)
        expect(response.status).to eq 302
      end
    end
  end
end
