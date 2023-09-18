require 'rails_helper'

RSpec.describe Event, type: :model do
  describe 'アソシエーションのテスト' do
    context 'Songモデルとの関係' do
      it 'songsと1:Nとなっている' do
        expect(Event.reflect_on_association(:songs).macro).to eq :has_many
      end
    end
    context 'Customerモデルとの関係' do
      it 'customerと1:Nとなっている' do
        expect(Event.reflect_on_association(:customer).macro).to eq :belongs_to
      end
    end
    context 'Communityモデルとの関係' do
      it 'communityと1:Nとなっている' do
        expect(Event.reflect_on_association(:community).macro).to eq :belongs_to
      end
    end
  end
end
