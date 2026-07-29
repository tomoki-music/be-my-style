require "rails_helper"

RSpec.describe "Public::Requests メンション通知", type: :request do
  let(:community) { create(:community) }
  let(:owner) { create(:customer, name: "オーナー") }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }
  let(:song) { event.songs.first }
  let(:poster) { create(:customer, name: "投稿者") }

  before do
    CommunityCustomer.find_or_create_by!(customer: poster, community: community)
    sign_in poster
  end

  def post_request(text)
    post public_event_requests_path(event_id: event.id), params: { request: { request: text } }, xhr: true
  end

  def notification_actions_for(customer)
    Notification.where(visited_id: customer.id).pluck(:action)
  end

  context "コミュニティメンバーかつイベント参加者がメンションされた場合" do
    it "mention_requestのみ作成され、request-msgは作成されないこと" do
      member_participant = create(:customer, name: "参加太郎")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      create(:join_part_customer, join_part: create(:join_part, song: song), customer: member_participant)

      post_request("[@参加太郎](customer:#{member_participant.id})お願いします")

      expect(notification_actions_for(member_participant)).to eq(["mention_request"])
    end
  end

  context "イベント参加者だがメンションされていない場合" do
    it "従来通りrequest-msg通知が作成されること" do
      member_participant = create(:customer, name: "参加花子")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      create(:join_part_customer, join_part: create(:join_part, song: song), customer: member_participant)

      post_request("メンションなしの投稿です")

      expect(notification_actions_for(member_participant)).to eq(["request-msg"])
    end
  end

  context "コミュニティメンバーだがイベント未参加の人がメンションされた場合" do
    it "mention_requestのみ作成されること(通常通知は作成されない)" do
      member_only = create(:customer, name: "興味太郎")
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)

      post_request("[@興味太郎](customer:#{member_only.id})お願いします")

      expect(notification_actions_for(member_only)).to eq(["mention_request"])
    end
  end

  context "コミュニティメンバーだがイベント未参加で、メンションもされていない場合" do
    it "通知が作成されないこと" do
      member_only = create(:customer, name: "傍観太郎")
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)

      post_request("メンションなしの投稿です")

      expect(notification_actions_for(member_only)).to be_empty
    end
  end

  context "イベント参加者だが開催元コミュニティのメンバーでない場合" do
    it "メンションしても通知されないが、従来通りrequest-msgは作成されること(通常通知とメンション仕様の混同防止)" do
      participant_not_member = create(:customer, name: "非会員参加者")
      create(:join_part_customer, join_part: create(:join_part, song: song), customer: participant_not_member)
      expect(CommunityCustomer.where(customer: participant_not_member, community: community)).to be_empty

      post_request("[@非会員参加者](customer:#{participant_not_member.id})お願いします")

      expect(notification_actions_for(participant_not_member)).to eq(["request-msg"])
    end
  end

  context "イベントオーナー" do
    it "参加登録もコミュニティ参加もしておらず、メンションもされていない場合、従来通りrequest-msgが作成されること" do
      expect(CommunityCustomer.where(customer: owner, community: community)).to be_empty

      post_request("メンションなしの投稿です")

      expect(notification_actions_for(owner)).to eq(["request-msg"])
    end

    it "コミュニティメンバーであり、メンションされた場合はmention_requestのみ作成されること" do
      CommunityCustomer.find_or_create_by!(customer: owner, community: community)

      post_request("[@オーナー](customer:#{owner.id})お願いします")

      expect(notification_actions_for(owner)).to eq(["mention_request"])
    end
  end

  it "投稿者本人には通常通知・メンション通知のいずれも作成されないこと" do
    post_request("[@ALL](customer:all)")

    expect(Notification.where(visited_id: poster.id)).to be_empty
  end

  describe "@ALL" do
    it "イベント未参加でもコミュニティの有効メンバー全員にmention_request通知が作成されること" do
      member_participant = create(:customer, name: "参加太郎")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      create(:join_part_customer, join_part: create(:join_part, song: song), customer: member_participant)

      member_only = create(:customer, name: "興味太郎")
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)

      post_request("[@ALL](customer:all)")

      expect(notification_actions_for(member_participant)).to eq(["mention_request"])
      expect(notification_actions_for(member_only)).to eq(["mention_request"])
    end

    it "他コミュニティのメンバーには通知されないこと" do
      other_community = create(:community)
      other_member = create(:customer, name: "他コミュニティ太郎")
      CommunityCustomer.find_or_create_by!(customer: other_member, community: other_community)

      post_request("[@ALL](customer:all)")

      expect(notification_actions_for(other_member)).to be_empty
    end

    it "参加登録していないオーナーには従来通りrequest-msg通知が作成されること(@ALLの対象外)" do
      post_request("[@ALL](customer:all)")

      expect(notification_actions_for(owner)).to eq(["request-msg"])
    end

    it "退会済みメンバーには通知されないこと" do
      member_only = create(:customer, name: "退会太郎")
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)
      member_only.update!(is_deleted: true)

      post_request("[@ALL](customer:all)")

      expect(notification_actions_for(member_only)).to be_empty
    end
  end

  it "@ALLと個別メンションが同時に書かれても、対象者への通知は1件だけであること" do
    member_participant = create(:customer, name: "参加太郎")
    CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
    create(:join_part_customer, join_part: create(:join_part, song: song), customer: member_participant)

    post_request("[@ALL](customer:all) [@参加太郎](customer:#{member_participant.id})")

    expect(Notification.where(visited_id: member_participant.id).count).to eq(1)
  end

  it "開催元コミュニティに参加していないCustomerのIDを本文へ直接書いても、その相手には通知が作成されないこと" do
    outsider = create(:customer, name: "コミュニティ未参加者")

    post_request("[@コミュニティ未参加者](customer:#{outsider.id})")

    expect(Notification.where(visited_id: outsider.id)).to be_empty
  end
end
