require "rails_helper"

RSpec.describe Chat::ChatRoomAuthorization, type: :service do
  describe "DM(community: nil)の場合" do
    let(:chat_room) { create(:chat_room) }
    let(:customer) { create(:customer) }

    it "chat_roomの参加者であればtrueを返すこと" do
      create(:chat_room_customer, chat_room: chat_room, customer: customer)

      expect(described_class.participant?(chat_room: chat_room, community: nil, customer: customer)).to eq true
    end

    it "chat_roomの参加者でなければfalseを返すこと" do
      expect(described_class.participant?(chat_room: chat_room, community: nil, customer: customer)).to eq false
    end
  end

  describe "コミュニティの場合" do
    let(:community) { create(:community) }
    let(:chat_room) { create(:chat_room) }
    let(:customer) { create(:customer) }

    it "コミュニティメンバーであればtrueを返すこと" do
      CommunityCustomer.find_or_create_by!(customer: customer, community: community)

      expect(described_class.participant?(chat_room: chat_room, community: community, customer: customer)).to eq true
    end

    it "コミュニティメンバーでなければfalseを返すこと" do
      expect(described_class.participant?(chat_room: chat_room, community: community, customer: customer)).to eq false
    end
  end

  describe "引数が不足している場合" do
    let(:chat_room) { create(:chat_room) }
    let(:customer) { create(:customer) }

    it "customerがnilならfalseを返すこと" do
      expect(described_class.participant?(chat_room: chat_room, community: nil, customer: nil)).to eq false
    end

    it "chat_roomがnilならfalseを返すこと" do
      expect(described_class.participant?(chat_room: nil, community: nil, customer: customer)).to eq false
    end
  end
end
