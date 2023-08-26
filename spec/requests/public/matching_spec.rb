require 'rails_helper'

RSpec.describe "matchingsコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "マッチングしたアーティト一覧ページが正しく表示される" do
      before do
        get public_matchings_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("チャットができるアーティスト一覧")
      end
    end
  end
  describe '非ログイン' do
    context "マッチングしたアーティト一覧ページへ遷移されない" do
      before do
        get public_matchings_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
  end
end
