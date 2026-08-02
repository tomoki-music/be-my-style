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
    let(:community) { create(:community) }
    let(:event) { create(:event, :event_with_songs, community: community) }
    let(:song) { event.songs.first }
    let(:member) { create(:customer, name: "参加太郎") }

    def join!(customer, target_song: song)
      join_part = create(:join_part, song: target_song)
      create(:join_part_customer, join_part: join_part, customer: customer)
    end

    before do
      CommunityCustomer.find_or_create_by!(customer: current_customer, community: community)
    end

    it "コミュニティメンバーであれば、イベント参加者でも候補に表示されること" do
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
      join!(member)

      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).to contain_exactly(member)
    end

    it "コミュニティメンバーであれば、イベント未参加でも候補に表示されること" do
      CommunityCustomer.find_or_create_by!(customer: member, community: community)

      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).to contain_exactly(member)
    end

    it "イベント参加者であってもコミュニティ非所属なら候補に表示されないこと" do
      join!(member) # memberはコミュニティに一切参加していない

      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(member)
    end

    it "コミュニティ所属を解除した場合は候補に表示されないこと" do
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
      join!(member)
      CommunityCustomer.find_by!(customer: member, community: community).destroy!

      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(member)
    end

    it "退会済み(is_deleted: true)のメンバーは候補に含まれないこと" do
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
      member.update!(is_deleted: true)

      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(member)
    end

    it "同一CommunityCustomerレコードが重複していても候補は1件であること" do
      CommunityCustomer.create!(customer: member, community: community)
      CommunityCustomer.create!(customer: member, community: community)

      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result.to_a.count { |customer| customer.id == member.id }).to eq(1)
    end

    it "自分自身は候補に含まれないこと" do
      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(current_customer)
    end

    it "他コミュニティのメンバーは候補に含まれないこと" do
      other_community = create(:community)
      other_member = create(:customer, name: "他コミュニティ太郎")
      CommunityCustomer.find_or_create_by!(customer: other_member, community: other_community)
      join!(other_member)

      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(other_member)
    end

    it "イベントオーナーであっても、コミュニティ非所属なら候補に含まれないこと" do
      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(event.customer)
    end

    it "イベントオーナーがコミュニティ所属メンバーであれば、参加登録していなくても候補に含まれること" do
      CommunityCustomer.find_or_create_by!(customer: event.customer, community: community)
      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).to include(event.customer)
    end

    it "管理者・オーナー・マネージャーであっても、対象コミュニティ非所属なら候補に含まれないこと" do
      admin = create(:customer, name: "管理者太郎", is_owner: :admin) # どのコミュニティにも未所属

      owner_outsider = create(:customer, name: "他コミュ会長")
      CommunityOwner.create!(customer: owner_outsider, community: create(:community)) # 別コミュニティのオーナー
      join!(owner_outsider) # このイベントには参加しているが対象コミュニティ非所属

      result = described_class.for_event(event: event, current_customer: current_customer)
      expect(result).not_to include(admin)
      expect(result).not_to include(owner_outsider)
    end

    it "queryで名前を部分一致検索できること" do
      CommunityCustomer.find_or_create_by!(customer: member, community: community)
      join!(member)

      result = described_class.for_event(event: event, current_customer: current_customer, query: "参加")
      expect(result).to contain_exactly(member)

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
