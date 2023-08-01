require 'rails_helper'

RSpec.describe "notificationsコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "notificationsの一覧ページが正しく表示される" do
      before do
        get public_notifications_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("通知一覧")
      end
    end
  end
  describe '非ログイン' do
    context "notifications一覧ページへ遷移されない" do
      before do
        get public_notifications_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
  end
end
