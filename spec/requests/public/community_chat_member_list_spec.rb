require "rails_helper"

# コミュニティチャット左側のメンバー一覧。chat_room_customers に同じ人の行が複数あっても
# Customer ID で1人1回だけ表示する(同名の別ユーザーは別人として両方表示する)。
RSpec.describe "コミュニティチャットのメンバー一覧", type: :request do
  let(:community) { create(:community) }
  let(:chat_room) { create(:chat_room) }
  let(:viewer) { create(:customer, name: "閲覧者") }
  let(:yurie) { create(:customer, name: "ゆりえ") }
  let(:toshi) { create(:customer, name: "トシ") }

  let(:doc) { Nokogiri::HTML(response.body) }

  def join!(customer)
    create(:chat_room_customer, chat_room: chat_room, customer: customer, community: community)
    CommunityCustomer.find_or_create_by!(customer: customer, community: community)
  end

  def member_names
    doc.css(".partner-index-container strong.do-chat").map { |node| node.text.strip }
  end

  def member_links
    doc.css(".partner-index-container a").map { |node| node["href"] }
  end

  before do
    join!(viewer)
    join!(yurie)
    join!(toshi)
  end

  it "同じ人の行が重複していても1回だけ表示し、参加人数も人数で数える" do
    # 過去の重複承認などで残った重複行を再現する
    create(:chat_room_customer, chat_room: chat_room, customer: yurie, community: community)
    create(:chat_room_customer, chat_room: chat_room, customer: toshi, community: community)
    create(:chat_room_customer, chat_room: chat_room, customer: yurie, community: community)

    sign_in viewer
    get community_show_public_chat_rooms_path(chat_room)

    expect(response).to have_http_status(:ok)
    expect(member_names).to eq ["閲覧者さん🎵", "ゆりえさん🎵", "トシさん🎵"]
    expect(member_links).to eq [viewer, yurie, toshi].map { |c| public_customer_path(c) }
    expect(doc.at_css(".partner-index-container > strong").text.strip).to eq "3人"
  end

  it "同じ表示名の別ユーザーは別人として両方表示する" do
    another_yurie = create(:customer, name: "ゆりえ")
    join!(another_yurie)

    sign_in viewer
    get community_show_public_chat_rooms_path(chat_room)

    expect(member_names.count("ゆりえさん🎵")).to eq 2
    expect(member_links).to include(public_customer_path(yurie), public_customer_path(another_yurie))
  end

  it "表示順は最初に参加した順(重複行の位置ではなく最初の行の位置)を保つ" do
    create(:chat_room_customer, chat_room: chat_room, customer: viewer, community: community)

    sign_in viewer
    get community_show_public_chat_rooms_path(chat_room)

    expect(member_names).to eq ["閲覧者さん🎵", "ゆりえさん🎵", "トシさん🎵"]
  end

  it "退会済みユーザーは重複行があっても表示しない" do
    create(:chat_room_customer, chat_room: chat_room, customer: toshi, community: community)
    toshi.update_columns(is_deleted: true)

    sign_in viewer
    get community_show_public_chat_rooms_path(chat_room)

    expect(member_names).not_to include("トシさん🎵")
  end

  it "コミュニティ非参加者は従来どおり閲覧できない" do
    outsider = create(:customer)
    sign_in outsider
    get community_show_public_chat_rooms_path(chat_room)

    expect(response.body).not_to include("ゆりえさん🎵")
  end
end
