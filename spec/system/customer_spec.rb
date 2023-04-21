require 'rails_helper'

describe 'Top画面からアーティスト一覧への遷移テスト' do
  let(:customer) { create(:customer) }
  before do
    visit new_customer_session_path
    fill_in 'customer[name]', with: customer.name
    fill_in 'customer[email]', with: customer.email
    fill_in 'customer[password]', with: customer.password
    click_button 'ログイン'
  end
  describe 'Top画面の表示のテスト' do
    context 'TOP画面' do
      before do
        visit public_homes_top_path
      end
      it 'Artist一覧ボタンが表示される' do
        expect(page).to have_content 'Artist一覧'
      end
    end
  end
  describe 'Artist一覧への遷移テスト' do
    context 'Artist一覧画面への遷移' do
      it '遷移できる' do
        visit public_customers_path
        expect(current_path).to eq('/public/customers')
      end
    end
  end
end