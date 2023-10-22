require 'rails_helper'

RSpec.describe Song, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }

  describe 'バリデーションのテスト' do
    context 'songテーブルのカラムが不正' do
      it 'song_nameカラムが空欄でないこと' do
        song.song_name = ''
        expect(song.valid?).to eq false
      end
    end
  end
  describe 'アソシエーションのテスト' do
    context 'Eventモデルとの関係' do
      it 'eventとN:1となっている' do
        expect(Song.reflect_on_association(:event).macro).to eq :belongs_to
      end
    end
    context 'customerモデルとの関係' do
      it 'customerモデルと1:Nとなっている' do
        expect(Song.reflect_on_association(:customers).macro).to eq :has_many
      end
      it '中間テーブルsong_customersと1:Nとなっている' do
        expect(Song.reflect_on_association(:song_customers).macro).to eq :has_many
      end
    end
  end
end
