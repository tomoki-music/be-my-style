require 'rails_helper'

RSpec.describe "customersコントローラーのテスト", type: :request do
  let(:customer) { create(:customer) }
  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "customer一覧ページが正しく表示される" do
      before do
        get public_customers_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
      it 'タイトルが正しく表示されていること' do
        expect(response.body).to include("アーティスト一覧")
      end
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
    context "customers一覧ページへ遷移されない" do
      before do
        get public_customers_path
      end
      it 'リクエストは302 Foundとなること' do
        expect(response.status).to eq 302
      end
    end
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
