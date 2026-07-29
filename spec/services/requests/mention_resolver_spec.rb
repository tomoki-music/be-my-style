require "rails_helper"

RSpec.describe Requests::MentionResolver, type: :service do
  let(:community) { create(:community) }
  let(:poster) { create(:customer, name: "投稿者") }
  let(:event) { create(:event, :event_with_songs, community: community) }
  let(:song) { event.songs.first }
  let(:member_a) { create(:customer, name: "参加太郎") }
  let(:member_b) { create(:customer, name: "参加花子") }

  before do
    CommunityCustomer.find_or_create_by!(customer: poster, community: community)
    CommunityCustomer.find_or_create_by!(customer: member_a, community: community)
    CommunityCustomer.find_or_create_by!(customer: member_b, community: community)
  end

  describe "個別メンション" do
    it "本文中の[@name](customer:ID)からコミュニティメンバーを解決すること" do
      text = "[@参加太郎](customer:#{member_a.id})お願いします"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(member_a)
    end

    it "イベントへ演奏参加登録していないコミュニティメンバーでも通知対象になること" do
      join_part = create(:join_part, song: song)
      expect(join_part.customers).not_to include(member_a) # member_aは一切joinしていない

      text = "[@参加太郎](customer:#{member_a.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(member_a)
    end

    it "複数の個別メンションを解決し、重複を排除すること" do
      text = "[@参加太郎](customer:#{member_a.id}) [@参加花子](customer:#{member_b.id}) " \
             "[@参加太郎](customer:#{member_a.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(member_a, member_b)
    end

    it "投稿者本人を本文中でメンションしても通知対象に含まれないこと" do
      text = "[@投稿者](customer:#{poster.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "イベントへ演奏参加していても、開催元コミュニティのメンバーでなければ通知対象に含まれないこと" do
      non_member_participant = create(:customer, name: "参加だけ花子")
      join_part = create(:join_part, song: song)
      create(:join_part_customer, join_part: join_part, customer: non_member_participant)

      text = "[@参加だけ花子](customer:#{non_member_participant.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "開催元コミュニティに参加していないCustomerのIDを本文へ直接書いても通知対象に含まれないこと" do
      outsider = create(:customer, name: "未参加者")
      text = "[@未参加者](customer:#{outsider.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "他コミュニティのメンバーIDを本文へ直接書いても通知対象に含まれないこと" do
      other_community = create(:community)
      other_member = create(:customer, name: "他コミュニティ太郎")
      CommunityCustomer.find_or_create_by!(customer: other_member, community: other_community)

      text = "[@他コミュニティ太郎](customer:#{other_member.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "退会済みメンバーは通知対象に含まれないこと" do
      member_a.update!(is_deleted: true)
      text = "[@参加太郎](customer:#{member_a.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "存在しないCustomer IDを本文へ書いても例外にならず、通知対象に含まれないこと" do
      text = "[@誰か](customer:999999)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "メンションを含まない本文では空配列を返すこと" do
      result = described_class.call(request_text: "オリジナル曲をお願いします", event: event, poster: poster)
      expect(result).to eq []
    end
  end

  describe "@ALL" do
    it "[@ALL](customer:all)を含む場合、投稿者を除く開催元コミュニティの有効メンバー全員を返すこと" do
      text = "[@ALL](customer:all) 見てください"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(member_a, member_b)
    end

    it "イベントへ演奏参加登録していないコミュニティメンバーも@ALLの対象になること" do
      join_part = create(:join_part, song: song)
      expect(join_part.customers).to be_empty # member_a/bともに一切joinしていない

      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(member_a, member_b)
    end

    it "投稿者自身は@ALLの対象に含まれないこと" do
      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).not_to include(poster)
    end

    it "退会済みメンバーは@ALLの対象に含まれないこと" do
      member_a.update!(is_deleted: true)
      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(member_b)
    end

    it "他コミュニティのメンバーは@ALLの対象に含まれないこと" do
      other_community = create(:community)
      other_member = create(:customer, name: "他コミュニティ太郎")
      CommunityCustomer.find_or_create_by!(customer: other_member, community: other_community)

      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).not_to include(other_member)
    end

    it "イベントオーナーでも開催元コミュニティのメンバーでなければ@ALLの対象に含まれないこと" do
      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).not_to include(event.customer)
    end

    it "@ALLと個別メンションが同時に書かれても対象は重複しないこと" do
      text = "[@ALL](customer:all) [@参加太郎](customer:#{member_a.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result.map(&:id).tally.values).to all(eq(1))
      expect(result).to contain_exactly(member_a, member_b)
    end
  end
end
