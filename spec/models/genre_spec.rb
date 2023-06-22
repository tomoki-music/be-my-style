require 'rails_helper'

RSpec.describe Genre, type: :model do
  describe 'アソシエーションのテスト' do
    context 'Customerモデルとの関係' do
      it 'customersと1:Nとなっている' do
        expect(Genre.reflect_on_association(:customers).macro).to eq :has_many
      end
      it '中間テーブルcustomer_genresと1:Nとなっている' do
        expect(Genre.reflect_on_association(:customer_genres).macro).to eq :has_many
      end
    end
    context 'Communityモデルとの関係' do
      it 'communitiesと1:Nとなっている' do
        expect(Genre.reflect_on_association(:communities).macro).to eq :has_many
      end
      it '中間テーブルcommunity_genresと1:Nとなっている' do
        expect(Genre.reflect_on_association(:community_genres).macro).to eq :has_many
      end
    end
  end
end
