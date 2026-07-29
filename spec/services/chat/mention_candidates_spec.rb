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

  describe ".for_event" do
    let(:event) { create(:event, :event_with_songs) }
    let(:song) { event.songs.first }
    let(:join_part) { create(:join_part, song: song) }
    let(:other_join_part) { create(:join_part, song: song) }
    let(:participant) { create(:customer, name: "参加太郎") }

    before do
      create(:join_part_customer, join_part: join_part, customer: current_customer)
      create(:join_part_customer, join_part: other_join_part, customer: participant)
    end

    it "現在のイベント参加者を候補として返すこと" do
      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).to contain_exactly(participant)
    end

    it "自分自身は候補に含まれないこと" do
      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(current_customer)
    end

    it "このイベントに参加していないCustomerは候補に含まれないこと" do
      non_participant = create(:customer, name: "未参加花子")
      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(non_participant)
    end

    it "同一人物が複数パートに参加していても候補に1件だけ現れること" do
      another_join_part = create(:join_part, song: song)
      create(:join_part_customer, join_part: another_join_part, customer: participant)

      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result.to_a.count { |c| c.id == participant.id }).to eq 1
    end

    it "退会済み(is_deleted: true)の参加者は候補に含まれないこと" do
      participant.update!(is_deleted: true)
      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(participant)
    end

    it "イベントオーナーでも参加登録していなければ候補に含まれないこと" do
      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(event.customer)
    end

    it "queryで名前を部分一致検索できること" do
      result = described_class.for_event(event: event, current_customer: current_customer, query: "参加")
      expect(result).to contain_exactly(participant)

      result_no_match = described_class.for_event(event: event, current_customer: current_customer, query: "zzz")
      expect(result_no_match).to be_empty
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
