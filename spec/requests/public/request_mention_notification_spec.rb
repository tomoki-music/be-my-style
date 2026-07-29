require "rails_helper"

RSpec.describe "Public::Requests メンション通知", type: :request do
  let(:poster) { create(:customer, name: "投稿者") }
  let(:owner) { create(:customer, name: "オーナー") }
  let(:community) { create(:community) }
  let(:event) { create(:event, :event_with_songs, customer: owner, community: community) }
  let(:song) { event.songs.first }
  let(:join_part_a) { create(:join_part, song: song) }
  let(:join_part_b) { create(:join_part, song: song) }
  let(:participant_a) { create(:customer, name: "参加太郎") }
  let(:participant_b) { create(:customer, name: "参加花子") }

  before do
    create(:join_part_customer, join_part: join_part_a, customer: poster)
    create(:join_part_customer, join_part: join_part_a, customer: participant_a)
    create(:join_part_customer, join_part: join_part_b, customer: participant_b)
    sign_in poster
  end

  def post_request(text)
    post public_event_requests_path(event_id: event.id), params: { request: { request: text } }, xhr: true
  end

  it "個別メンションされた相手にはmention_request通知のみが作成され、request-msg通知は作成されないこと" do
    post_request("[@参加太郎](customer:#{participant_a.id})お願いします")

    notifications = Notification.where(visited_id: participant_a.id)
    expect(notifications.pluck(:action)).to eq(["mention_request"])
  end

  it "メンションされていない参加者には従来通りrequest-msg通知が作成されること" do
    post_request("[@参加太郎](customer:#{participant_a.id})お願いします")

    notifications = Notification.where(visited_id: participant_b.id)
    expect(notifications.pluck(:action)).to eq(["request-msg"])
  end

  it "投稿者本人には通常通知・メンション通知のいずれも作成されないこと" do
    post_request("[@ALL](customer:all)")

    expect(Notification.where(visited_id: poster.id)).to be_empty
  end

  it "@ALLの場合、参加しているオーナーを含む全参加者にmention_request通知が1件ずつ作成されること" do
    create(:join_part_customer, join_part: join_part_b, customer: owner)

    post_request("[@ALL](customer:all)")

    expect(Notification.where(visited_id: owner.id).pluck(:action)).to eq(["mention_request"])
    expect(Notification.where(visited_id: participant_a.id).pluck(:action)).to eq(["mention_request"])
    expect(Notification.where(visited_id: participant_b.id).pluck(:action)).to eq(["mention_request"])
  end

  it "参加登録していないオーナーには従来通りrequest-msg通知が作成されること(@ALLの対象外)" do
    post_request("[@ALL](customer:all)")

    expect(Notification.where(visited_id: owner.id).pluck(:action)).to eq(["request-msg"])
  end

  it "@ALLと個別メンションが同時に書かれても、対象者への通知は1件だけであること" do
    post_request("[@ALL](customer:all) [@参加太郎](customer:#{participant_a.id})")

    expect(Notification.where(visited_id: participant_a.id).count).to eq(1)
  end

  it "本文に未参加者のcustomer_idを直接書いても、その相手には通知が作成されないこと" do
    outsider = create(:customer, name: "未参加者")
    post_request("[@未参加者](customer:#{outsider.id})")

    expect(Notification.where(visited_id: outsider.id)).to be_empty
  end

  it "退会済み参加者には通知が作成されないこと" do
    participant_a.update!(is_deleted: true)
    post_request("[@ALL](customer:all)")

    expect(Notification.where(visited_id: participant_a.id)).to be_empty
  end
end
