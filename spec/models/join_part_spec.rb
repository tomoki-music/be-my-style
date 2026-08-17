require 'rails_helper'

RSpec.describe JoinPart, type: :model do
  let(:customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:other_customer) { FactoryBot.create(:customer, :customer_with_parts) }
  let(:community) { FactoryBot.create(:community) }
  let(:event) { FactoryBot.create(:event, :event_with_songs, customer: customer, community: community) }
  let(:song) { FactoryBot.create(:song, event: event) }
  let(:join_part) { FactoryBot.create(:join_part, song: song) }

  describe 'バリデーションのテスト' do
    context 'join_partテーブルのカラムが不正' do
      it 'join_part_nameカラムが空欄でないこと' do
        join_part.join_part_name = ''
        expect(join_part.valid?).to eq false
      end
    end
  end

  describe 'アソシエーションのテスト' do
    context 'Songモデルとの関係' do
      it 'songとN:1となっている' do
        expect(JoinPart.reflect_on_association(:song).macro).to eq :belongs_to
      end
    end
    context 'customerモデルとの関係' do
      it 'customerモデルと1:Nとなっている' do
        expect(JoinPart.reflect_on_association(:customers).macro).to eq :has_many
      end
      it '中間テーブルjoin_part_customersと1:Nとなっている' do
        expect(JoinPart.reflect_on_association(:join_part_customers).macro).to eq :has_many
      end
    end
  end

  describe '#active_customers' do
    it '退会済み(is_deleted: true)の参加者を除外すること' do
      withdrawn_customer = FactoryBot.create(:customer, is_deleted: true)
      JoinPartCustomer.create!(join_part: join_part, customer: customer)
      JoinPartCustomer.create!(join_part: join_part, customer: withdrawn_customer)

      expect(join_part.active_customers).to include(customer)
      expect(join_part.active_customers).not_to include(withdrawn_customer)
      # JoinPartCustomerレコード自体は削除されない
      expect(JoinPartCustomer.exists?(join_part: join_part, customer: withdrawn_customer)).to eq true
    end
  end
end
