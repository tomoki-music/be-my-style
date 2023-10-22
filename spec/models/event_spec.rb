require 'rails_helper'

RSpec.describe Event, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }

  describe 'バリデーションのテスト' do
    context 'eventテーブルのカラムが不正' do
      it 'event_nameカラムが空欄でないこと' do
        event.event_name = ''
        expect(event.valid?).to eq false
      end
      it 'event_dateが空欄でないこと' do
        event.event_date = ''
        expect(event.valid?).to eq false
      end
      it 'entrance_feeが空欄でないこと' do
        event.entrance_fee = ''
        expect(event.valid?).to eq false
      end
      it 'addressが空欄でないこと' do
        event.address = ''
        expect(event.valid?).to eq false
      end
    end
  end
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
