require 'rails_helper'

RSpec.describe CustomerGenre, type: :model do
  describe 'アソシエーションのテスト' do
    context '親モデルとの関係' do
      it 'customerとN:1となっている' do
        expect(CustomerGenre.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'genreとN:1となっている' do
        expect(CustomerGenre.reflect_on_association(:genre).macro).to eq :belongs_to
      end
    end
  end
end
