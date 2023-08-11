require 'rails_helper'

RSpec.describe "Public::Activities", type: :request do
  let(:customer) { create(:customer) }
  let(:activity) { create(:activity, customer: customer) }

  describe 'ログイン済み' do
    before do
      sign_in customer
    end
    context "activity一覧ページ(index)が正しく表示される" do
      before do
        get public_customer_activities_path
      end
      it 'リクエストは200 OKとなること' do
        expect(response.status).to eq 200
      end
    end
  end

  describe '非ログイン' do

  end
end
