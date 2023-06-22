require 'rails_helper'

RSpec.describe CommunityGenre, type: :model do
  describe 'アソシエーションのテスト' do
    context '親モデルとの関係' do
      it 'communityとN:1となっている' do
        expect(CommunityGenre.reflect_on_association(:community).macro).to eq :belongs_to
      end
      it 'genreとN:1となっている' do
        expect(CommunityGenre.reflect_on_association(:genre).macro).to eq :belongs_to
      end
    end
  end
end
