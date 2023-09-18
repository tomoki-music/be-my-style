require 'rails_helper'

RSpec.describe Song, type: :model do
  describe 'アソシエーションのテスト' do
    context 'Eventモデルとの関係' do
      it 'eventと1:Nとなっている' do
        expect(Song.reflect_on_association(:event).macro).to eq :belongs_to
      end
    end
  end
end
