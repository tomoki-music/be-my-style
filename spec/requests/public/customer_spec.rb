require 'rails_helper'

RSpec.describe "customersコントローラーのテスト", type: :request do
  let(:customer) { create(:customer, :customer_with_parts) }
  let(:customer2) { create(:customer, :customer_with_parts) }
  let(:customer3) { create(:customer, :customer_with_parts) }
  let(:community) { create(:community) }
  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "customer詳細ページが正しく表示される" do
      before do
        get public_customer_path(customer)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("アーティスト詳細")
      end
    end
    context "同じcommunity内のcustomer詳細ページは表示される" do
      before do
        get public_community_join_path(community)
        sign_in customer2
        get public_community_join_path(community)
        get public_customer_path(customer)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("アーティスト詳細")
      end
    end
    context "同じcommunityでないcustomer詳細ページは表示されない" do
      before do
        get public_community_join_path(community)
        sign_in customer3
        get public_customer_path(customer)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
      it 'コミュニティ一覧へリダイレクトされる' do
        expect(response).to redirect_to('http://www.example.com/public/communities')
      end
    end
    context "customer編集ページが正しく表示される" do
      before do
        get edit_public_customer_path(customer)
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("アーティスト編集画面")
      end
    end
  end
  describe '非ログイン' do
    context "customers詳細ページへ遷移されない" do
      before do
        get public_customer_path(customer)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
    context "customers編集ページへ遷移されない" do
      before do
        get edit_public_customer_path(customer)
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
  end
end
