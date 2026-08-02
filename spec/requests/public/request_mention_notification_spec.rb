require "rails_helper"

RSpec.describe "Public::Requests メンション通知", type: :request do
  include ActiveJob::TestHelper

  let(:community) { create(:community) }
  let(:owner) { create(:customer, name: "オーナー") }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }
  let(:song) { event.songs.first }
  let(:poster) { create(:customer, name: "投稿者") }

  def join!(customer, target_song: song)
    join_part = create(:join_part, song: target_song)
    create(:join_part_customer, join_part: join_part, customer: customer)
  end

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
      join!(member_participant)

      post_request("[@参加太郎](customer:#{member_participant.id})お願いします")

      expect(notification_actions_for(member_participant)).to eq(["mention_request"])
    end
  end

  context "イベント参加者だがメンションされていない場合" do
    it "従来通りrequest-msg通知が作成されること" do
      member_participant = create(:customer, name: "参加花子")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      join!(member_participant)

      post_request("メンションなしの投稿です")

      expect(notification_actions_for(member_participant)).to eq(["request-msg"])
    end
  end

  context "コミュニティメンバーだがイベント未参加の人がメンションされた場合" do
    it "mention_requestが作成されること(通常通知は対象外のまま)" do
      member_only = create(:customer, name: "興味太郎")
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)

      post_request("[@興味太郎](customer:#{member_only.id})お願いします")

      expect(notification_actions_for(member_only)).to eq(["mention_request"])
    end
  end

  context "イベント参加者だが開催元コミュニティのメンバーでない場合" do
    it "メンションしても通知されないこと(通常通知は従来通り作成される)" do
      participant_not_member = create(:customer, name: "非会員参加者")
      join!(participant_not_member)
      expect(CommunityCustomer.where(customer: participant_not_member, community: community)).to be_empty

      post_request("[@非会員参加者](customer:#{participant_not_member.id})お願いします")

      expect(notification_actions_for(participant_not_member)).to eq(["request-msg"])
    end
  end

  context "参加後にコミュニティ所属を解除した場合" do
    it "メンションしても通知されないこと" do
      member_participant = create(:customer, name: "退会参加太郎")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      join!(member_participant)
      CommunityCustomer.find_by!(customer: member_participant, community: community).destroy!

      post_request("[@退会参加太郎](customer:#{member_participant.id})お願いします")

      expect(notification_actions_for(member_participant)).to eq(["request-msg"])
    end
  end

  context "参加後にJoinPartCustomerを削除した場合" do
    it "コミュニティメンバーであればメンションでmention_requestが作成されること" do
      member_participant = create(:customer, name: "取消太郎")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      join_part = create(:join_part, song: song)
      join_part_customer = create(:join_part_customer, join_part: join_part, customer: member_participant)
      join_part_customer.destroy!

      post_request("[@取消太郎](customer:#{member_participant.id})お願いします")

      expect(notification_actions_for(member_participant)).to eq(["mention_request"])
    end
  end

  context "イベントオーナー" do
    it "参加登録もコミュニティ参加もしておらず、メンションもされていない場合、従来通りrequest-msgが作成されること" do
      expect(CommunityCustomer.where(customer: owner, community: community)).to be_empty

      post_request("メンションなしの投稿です")

      expect(notification_actions_for(owner)).to eq(["request-msg"])
    end

    it "コミュニティメンバーかつ参加登録済みで、メンションされた場合はmention_requestのみ作成されること" do
      CommunityCustomer.find_or_create_by!(customer: owner, community: community)
      join!(owner)

      post_request("[@オーナー](customer:#{owner.id})お願いします")

      expect(notification_actions_for(owner)).to eq(["mention_request"])
    end

    it "コミュニティメンバーであれば、参加登録していなくてもメンションでmention_requestが作成されること" do
      CommunityCustomer.find_or_create_by!(customer: owner, community: community)

      post_request("[@オーナー](customer:#{owner.id})お願いします")

      # ownerはevent.customerとして通常通知(request-msg)の対象にもなるが、
      # mentioned_customer_idsに含まれるためrequest-msgは送られず、mention_requestのみ作成される。
      expect(notification_actions_for(owner)).to eq(["mention_request"])
    end
  end

  context "管理者・オーナー・マネージャー" do
    it "対象コミュニティ非所属なら通知対象外であること" do
      admin = create(:customer, name: "管理者太郎", is_owner: :admin) # どのコミュニティにも未所属

      post_request("[@管理者太郎](customer:#{admin.id})お願いします")

      expect(notification_actions_for(admin)).to be_empty
    end

    it "コミュニティメンバーであれば、参加登録なしでもメンションでmention_requestが作成されること" do
      admin = create(:customer, name: "管理者太郎", is_owner: :admin)
      CommunityCustomer.find_or_create_by!(customer: admin, community: community) # 参加登録なし

      post_request("[@管理者太郎](customer:#{admin.id})お願いします")

      expect(notification_actions_for(admin)).to eq(["mention_request"])
    end
  end

  it "投稿者本人には通常通知・メンション通知のいずれも作成されないこと" do
    post_request("[@ALL](customer:all)")

    expect(Notification.where(visited_id: poster.id)).to be_empty
  end

  describe "@ALL" do
    it "開催元コミュニティの有効メンバー全員にmention_request通知が作成されること" do
      member_participant = create(:customer, name: "参加太郎")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      join!(member_participant)

      post_request("[@ALL](customer:all)")

      expect(notification_actions_for(member_participant)).to eq(["mention_request"])
    end

    it "コミュニティメンバーであれば、イベント未参加でも通知されること" do
      member_only = create(:customer, name: "興味太郎")
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)

      post_request("[@ALL](customer:all)")

      expect(notification_actions_for(member_only)).to eq(["mention_request"])
    end

    it "他コミュニティのメンバーには通知されないこと" do
      other_community = create(:community)
      other_member = create(:customer, name: "他コミュニティ太郎")
      CommunityCustomer.find_or_create_by!(customer: other_member, community: other_community)

      post_request("[@ALL](customer:all)")

      expect(notification_actions_for(other_member)).to be_empty
    end

    it "コミュニティ非所属のオーナーには従来通りrequest-msg通知が作成されること(@ALLの対象外)" do
      post_request("[@ALL](customer:all)")

      expect(notification_actions_for(owner)).to eq(["request-msg"])
    end

    it "退会済みメンバーには通知されないこと" do
      member_only = create(:customer, name: "退会太郎")
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)
      join!(member_only)
      member_only.update!(is_deleted: true)

      post_request("[@ALL](customer:all)")

      expect(notification_actions_for(member_only)).to be_empty
    end
  end

  it "@ALLと個別メンションが同時に書かれても、対象者への通知は1件だけであること" do
    member_participant = create(:customer, name: "参加太郎")
    CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
    join!(member_participant)

    post_request("[@ALL](customer:all) [@参加太郎](customer:#{member_participant.id})")

    expect(Notification.where(visited_id: member_participant.id).count).to eq(1)
  end

  it "開催元コミュニティに所属していないCustomerのIDを本文へ直接書いても、その相手には通知が作成されないこと" do
    outsider = create(:customer, name: "コミュニティ未所属者")

    post_request("[@コミュニティ未所属者](customer:#{outsider.id})")

    expect(Notification.where(visited_id: outsider.id)).to be_empty
  end

  describe "メール通知" do
    def mails_to(customer)
      ActionMailer::Base.deliveries.select { |mail| mail.to == [customer.email] }
    end

    it "メンションされたユーザーにmention_request_mailが1通送信されること" do
      member_participant = create(:customer, name: "参加太郎")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      join!(member_participant)

      perform_enqueued_jobs do
        post_request("[@参加太郎](customer:#{member_participant.id})お願いします")
      end

      mails = mails_to(member_participant)
      expect(mails.size).to eq(1)
      expect(mails.first.subject).to eq("【BeMyStyle】イベントリクエストでメンションされました")
    end

    it "confirm_mailがfalseのユーザーにはメールが送信されないこと" do
      member_only = create(:customer, name: "配信停止太郎", confirm_mail: false)
      CommunityCustomer.find_or_create_by!(customer: member_only, community: community)
      join!(member_only)

      perform_enqueued_jobs do
        post_request("[@配信停止太郎](customer:#{member_only.id})お願いします")
      end

      expect(mails_to(member_only)).to be_empty
    end

    it "@ALLと個別メンションが同時に書かれても、対象者へのメールは1通だけであること" do
      member_participant = create(:customer, name: "参加太郎")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      join!(member_participant)

      perform_enqueued_jobs do
        post_request("[@ALL](customer:all) [@参加太郎](customer:#{member_participant.id})")
      end

      expect(mails_to(member_participant).size).to eq(1)
    end

    it "メンションされていない通常通知対象者には従来通りrequest_msg_mailのみ送信されること(メンション通知メールと重複しない)" do
      member_participant = create(:customer, name: "参加花子")
      CommunityCustomer.find_or_create_by!(customer: member_participant, community: community)
      join!(member_participant)

      perform_enqueued_jobs do
        post_request("メンションなしの投稿です")
      end

      mails = mails_to(member_participant)
      expect(mails.size).to eq(1)
      expect(mails.first.subject).to eq("参加したイベントにリクエストがありました！")
    end

    it "投稿者本人にはメールが送信されないこと" do
      perform_enqueued_jobs do
        post_request("[@ALL](customer:all)")
      end

      expect(mails_to(poster)).to be_empty
    end
  end
end
