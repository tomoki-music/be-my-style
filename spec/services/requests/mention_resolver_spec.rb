require "rails_helper"

RSpec.describe Requests::MentionResolver, type: :service do
  let(:community) { create(:community) }
  let(:poster) { create(:customer, name: "投稿者") }
  let(:event) { create(:event, :event_with_songs, community: community) }
  let(:song) { event.songs.first }
  let(:member_a) { create(:customer, name: "参加太郎") }
  let(:member_b) { create(:customer, name: "参加花子") }

  def join!(customer, target_song: song)
    join_part = create(:join_part, song: target_song)
    create(:join_part_customer, join_part: join_part, customer: customer)
  end

  before do
    CommunityCustomer.find_or_create_by!(customer: poster, community: community)
    CommunityCustomer.find_or_create_by!(customer: member_a, community: community)
    CommunityCustomer.find_or_create_by!(customer: member_b, community: community)
    join!(member_a)
    join!(member_b)
  end

  describe "個別メンション" do
    it "本文中の[@name](customer:ID)から開催元コミュニティのメンバーを解決すること" do
      text = "[@参加太郎](customer:#{member_a.id})お願いします"
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

    it "コミュニティメンバーであれば、イベント未参加でも本文へ書けば通知対象に含まれること" do
      member_only = create(:customer, name: "興味太郎")
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)

      text = "[@興味太郎](customer:#{member_only.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(member_only)
    end

    it "イベントへ演奏参加していても、開催元コミュニティのメンバーでなければ通知対象に含まれないこと" do
      non_member_participant = create(:customer, name: "参加だけ花子")
      join!(non_member_participant)

      text = "[@参加だけ花子](customer:#{non_member_participant.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "コミュニティ所属を解除した場合、本文へ書いても通知対象に含まれないこと" do
      CommunityCustomer.find_by!(customer: member_a, community: community).destroy!

      text = "[@参加太郎](customer:#{member_a.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "JoinPartCustomerを削除して未参加になっても、コミュニティメンバーであれば通知対象に含まれること" do
      JoinPartCustomer.find_by!(customer: member_a).destroy!

      text = "[@参加太郎](customer:#{member_a.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(member_a)
    end

    it "開催元コミュニティに所属していないCustomerのIDを本文へ直接書いても通知対象に含まれないこと" do
      outsider = create(:customer, name: "未所属者")
      text = "[@未所属者](customer:#{outsider.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "他コミュニティのメンバーIDを本文へ直接書いても通知対象に含まれないこと" do
      other_community = create(:community)
      other_member = create(:customer, name: "他コミュニティ太郎")
      CommunityCustomer.find_or_create_by!(customer: other_member, community: other_community)
      join!(other_member)

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

    it "管理者・オーナー・マネージャーであっても、対象コミュニティ非所属なら通知対象に含まれないこと" do
      admin = create(:customer, name: "管理者太郎", is_owner: :admin) # どのコミュニティにも未所属

      text = "[@管理者太郎](customer:#{admin.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to be_empty
    end

    it "管理者であっても、コミュニティメンバーであれば参加登録なしで通知対象に含まれること" do
      admin = create(:customer, name: "管理者太郎", is_owner: :admin)
      CommunityCustomer.find_or_create_by!(customer: admin, community: community) # 参加登録なし

      text = "[@管理者太郎](customer:#{admin.id})"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(admin)
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

    it "コミュニティメンバーであれば、イベント未参加でも@ALLの対象になること" do
      member_only = create(:customer, name: "興味太郎")
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)

      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to include(member_only)
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

    it "参加後にコミュニティ所属を解除したメンバーは@ALLの対象に含まれないこと" do
      CommunityCustomer.find_by!(customer: member_a, community: community).destroy!
      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to contain_exactly(member_b)
    end

    it "他コミュニティのメンバーは@ALLの対象に含まれないこと" do
      other_community = create(:community)
      other_member = create(:customer, name: "他コミュニティ太郎")
      CommunityCustomer.find_or_create_by!(customer: other_member, community: other_community)
      join!(other_member)

      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).not_to include(other_member)
    end

    it "イベントオーナーがコミュニティ所属メンバーであれば、参加登録していなくても@ALLの対象に含まれること" do
      CommunityCustomer.find_or_create_by!(customer: event.customer, community: community)
      text = "[@ALL](customer:all)"
      result = described_class.call(request_text: text, event: event, poster: poster)
      expect(result).to include(event.customer)
    end

    it "イベントオーナーであっても、コミュニティ非所属なら@ALLの対象に含まれないこと" do
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
