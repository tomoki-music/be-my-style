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
  end
  describe '非ログイン' do
    context "customers一覧ページへ遷移されない" do
      before do
        get public_customers_path(customer)
      end
      it 'リクエストは401 OKとなること' do
        expect(response.status).to eq 401
      end
    end
  end
end
