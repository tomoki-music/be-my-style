require 'rails_helper'

RSpec.describe Request, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:join_part) { FactoryBot.create(:join_part, song: song) }
  let(:song) { FactoryBot.create(:song, :song_with_parts, event: event) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:request) { FactoryBot.create(:request, customer_id: other_customer.id, event_id: event.id) }

  describe 'リクエストの投稿テスト' do
    context 'リクエスト投稿できる場合' do
      it 'リクエスト入力済みあれば投稿できる' do
        expect(request).to be_valid
      end
    end

    context '投稿できない場合' do
      it 'リクエストが空では投稿できない' do
        request.request = ''
        expect(request).to be_invalid
      end
    end
  end

  describe 'アソシエーションのテスト' do
    context 'リクエスト機能について' do
      it 'customersとN:1となっている' do
        expect(Request.reflect_on_association(:customer).macro).to eq :belongs_to
      end
      it 'activitiesとN:1となっている' do
        expect(Request.reflect_on_association(:event).macro).to eq :belongs_to
      end
    end
  end
end
