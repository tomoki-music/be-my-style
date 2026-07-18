require "rails_helper"

RSpec.describe Chat::MentionCandidates, type: :service do
  let(:current_customer) { create(:customer, name: "Tomoki") }

  describe ".for_chat_room" do
    let(:other_customer) { create(:customer, name: "Yuki") }
    let(:chat_room) { create(:chat_room) }

    before do
      create(:chat_room_customer, chat_room: chat_room, customer: current_customer)
      create(:chat_room_customer, chat_room: chat_room, customer: other_customer)
    end

    it "DM相手を候補として返すこと" do
      result = described_class.for_chat_room(chat_room: chat_room, current_customer: current_customer)
      expect(result).to contain_exactly(other_customer)
    end

    it "自分自身は候補に含まれないこと" do
      result = described_class.for_chat_room(chat_room: chat_room, current_customer: current_customer)
      expect(result).not_to include(current_customer)
    end

    it "queryで名前を部分一致・大文字小文字を区別せず絞り込めること" do
      result = described_class.for_chat_room(chat_room: chat_room, current_customer: current_customer, query: "yu")
      expect(result).to contain_exactly(other_customer)

      result_no_match = described_class.for_chat_room(chat_room: chat_room, current_customer: current_customer, query: "zzz")
      expect(result_no_match).to be_empty
    end

    it "検索文字列が自分の名前と一致しても自分自身は含まれないこと" do
      result = described_class.for_chat_room(chat_room: chat_room, current_customer: current_customer, query: "Tomoki")
      expect(result).not_to include(current_customer)
      expect(result).to be_empty
    end

    it "自分と同名の別ユーザーがいる場合、その別ユーザーは候補に残ること" do
      namesake = create(:customer, name: "Tomoki")
      create(:chat_room_customer, chat_room: chat_room, customer: namesake)

      result = described_class.for_chat_room(chat_room: chat_room, current_customer: current_customer, query: "Tomoki")
      expect(result).to contain_exactly(namesake)
      expect(result).not_to include(current_customer)
    end
  end

  describe ".for_community" do
    let(:community) { create(:community) }
    let(:member) { create(:customer, name: "メンバー太郎") }
    let(:non_member) { create(:customer, name: "非メンバー") }

    before do
      CommunityCustomer.find_or_create_by!(customer: current_customer, community: community)
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
    end

    it "実際のコミュニティメンバー(CommunityCustomer)のみを候補として返すこと" do
      result = described_class.for_community(community: community, current_customer: current_customer)
      expect(result).to contain_exactly(member)
      expect(result).not_to include(non_member)
    end

    it "自分自身は候補に含まれないこと" do
      result = described_class.for_community(community: community, current_customer: current_customer)
      expect(result).not_to include(current_customer)
    end

    it "日本語名で部分一致検索できること" do
      result = described_class.for_community(community: community, current_customer: current_customer, query: "太郎")
      expect(result).to contain_exactly(member)
    end

    it "検索文字列が自分の名前と一致しても自分自身は含まれないこと" do
      result = described_class.for_community(community: community, current_customer: current_customer, query: "Tomoki")
      expect(result).not_to include(current_customer)
      expect(result).to be_empty
    end

    it "自分と同名の別ユーザーがいる場合、その別ユーザーは候補に残ること" do
      namesake = create(:customer, name: "Tomoki")
      CommunityCustomer.find_or_create_by!(customer: namesake, community: community)

      result = described_class.for_community(community: community, current_customer: current_customer, query: "Tomoki")
      expect(result).to contain_exactly(namesake)
      expect(result).not_to include(current_customer)
    end
  end

  describe "最大件数" do
    it "MAX_RESULTSを超える候補は切り詰められること" do
      chat_room = create(:chat_room)
      create(:chat_room_customer, chat_room: chat_room, customer: current_customer)
      (described_class::MAX_RESULTS + 5).times do |i|
        create(:chat_room_customer, chat_room: chat_room, customer: create(:customer, name: "候補#{i}"))
      end

      result = described_class.for_chat_room(chat_room: chat_room, current_customer: current_customer)
      expect(result.size).to eq described_class::MAX_RESULTS
    end
  end
end
