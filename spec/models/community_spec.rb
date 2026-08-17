require 'rails_helper'

RSpec.describe 'Communityモデルのテスト', type: :model do
  let(:community) { FactoryBot.create(:community) }

  describe 'バリデーションのテスト' do
    context 'nameカラムが不正' do
      it '空欄でないこと' do
        community.name = ''
        expect(community.valid?).to eq false
      end
      it '16文字以上でないこと' do
        community.name = 'コミュニティの名前が１６文字です'
        expect(community.valid?).to eq false
      end
    end
    context 'introductionカラムが不正' do
      it '空欄でないこと' do
        community.introduction = ''
        expect(community.valid?).to eq false
      end
    end
  end
  describe 'アソシエーションのテスト' do
    context 'Customerモデルとの関係' do
      it 'customersと1:Nとなっている' do
        expect(Community.reflect_on_association(:customers).macro).to eq :has_many
      end
      it '中間テーブルcommunity_customersと1:Nとなっている' do
        expect(Community.reflect_on_association(:community_customers).macro).to eq :has_many
      end
    end
    context 'ChatRoomCustomerモデルとの関係' do
      it 'chat_room_customersと1:Nとなっている' do
        expect(Community.reflect_on_association(:chat_room_customers).macro).to eq :has_many
      end
      it 'customersと1:Nとなっている' do
        expect(Community.reflect_on_association(:customers).macro).to eq :has_many
      end
      it 'chat_roomsと1:Nとなっている' do
        expect(Community.reflect_on_association(:chat_rooms).macro).to eq :has_many
      end
      it 'chat_messagesと1:Nとなっている' do
        expect(Community.reflect_on_association(:chat_messages).macro).to eq :has_many
      end
    end
    context 'Genreモデルとの関係' do
      it 'genresと1:Nとなっている' do
        expect(Community.reflect_on_association(:genres).macro).to eq :has_many
      end
      it '中間テーブルcommunity_genresと1:Nとなっている' do
        expect(Community.reflect_on_association(:community_genres).macro).to eq :has_many
      end
    end
    context 'Permitモデルとの関係' do
      it 'permitと1:Nとなっている' do
        expect(Community.reflect_on_association(:permits).macro).to eq :has_many
      end
    end
    context 'Eventモデルとの関係' do
      it 'eventと1:Nとなっている' do
        expect(Community.reflect_on_association(:events).macro).to eq :has_many
      end
    end
    context 'CommunityEventEditorモデルとの関係' do
      it '中間テーブルcommunity_event_editorsと1:Nとなっている' do
        expect(Community.reflect_on_association(:community_event_editors).macro).to eq :has_many
      end
      it 'event_editorsと1:Nとなっている' do
        expect(Community.reflect_on_association(:event_editors).macro).to eq :has_many
      end
    end
  end

  describe '#active_customers' do
    it '退会済み(is_deleted: true)のメンバーを除外すること' do
      active_member = FactoryBot.create(:customer, is_deleted: false)
      withdrawn_member = FactoryBot.create(:customer, is_deleted: true)
      CommunityCustomer.create!(community: community, customer: active_member)
      CommunityCustomer.create!(community: community, customer: withdrawn_member)

      expect(community.active_customers).to include(active_member)
      expect(community.active_customers).not_to include(withdrawn_member)
      # CommunityCustomerレコード自体は削除されない
      expect(CommunityCustomer.exists?(community: community, customer: withdrawn_member)).to eq true
    end
  end
end
