require "rails_helper"

# ホーム(/business)とメニューの「コミュニティ」(/business/communities)で、コミュニティの表示範囲を分ける。
#   ホーム: 公開・閲覧条件の範囲内(Business コミュニティ全件)。参加済み・未参加・承認待ちを状態付きで出す。
#   一覧  : 本人が参加済み(community_customers の行がある)のものだけ。承認待ち・未参加・停止中は出さない。
RSpec.describe "Business コミュニティの表示範囲(ホームと一覧)", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:viewer) { create(:customer, domain_name: "business", onboarding_done: true) }

  def business_community(name, mode: :auto)
    create(:community, owner: owner, domain: business_domain, name: name, join_approval_mode: mode).tap do |community|
      CommunityCustomer.create!(community: community, customer: owner)
    end
  end

  let!(:joined) { business_community("参加済みの会").tap { |c| CommunityCustomer.create!(community: c, customer: viewer) } }
  let!(:unjoined) { business_community("未参加の会") }
  let!(:pending) { business_community("承認待ちの会", mode: :manual).tap { |c| Permit.create!(community: c, customer: viewer) } }
  let!(:suspended) { business_community("停止中の会").tap { |c| CommunityAccessSuspension.create!(community: c, customer: viewer) } }
  let!(:music_community) do
    create(:community, owner: owner, domain: music_domain, name: "音楽の会").tap do |c|
      CommunityCustomer.create!(community: c, customer: viewer)
    end
  end

  before { sign_in viewer }

  def doc
    Nokogiri::HTML(response.body)
  end

  def home_items
    doc.css("#my-communities .ba-circle-item").to_h do |item|
      [item.at_css(".ba-circle-item__name").text.strip, item.at_css(".ba-status").text.strip]
    end
  end

  def tile_names
    doc.css(".ba-community-tile__name").map { |name| name.text.strip }
  end

  it "ホームは参加済み・未参加・承認待ちを状態付きで出し、音楽コミュニティは出さない" do
    get business_root_path

    expect(response).to have_http_status(:ok)
    expect(home_items).to eq(
      "停止中の会" => "アクセス停止中",
      "承認待ちの会" => "承認待ち",
      "未参加の会" => "自動承認",
      "参加済みの会" => "参加中"
    )
    expect(doc.at_css("#my-communities .ba-count").text).to eq "4件"
    expect(doc.at_css(%(#my-communities a[href="#{business_community_path(unjoined)}"]))).to be_present
    expect(doc.at_css(%(#my-communities a[href="#{business_communities_path}"])).text.strip).to eq "参加中のコミュニティ"
  end

  it "メニューの「コミュニティ」一覧は参加済みだけを出し、承認待ち・未参加・停止中・音楽は出さない" do
    get business_communities_path

    expect(response).to have_http_status(:ok)
    expect(tile_names).to eq ["参加済みの会"]
    expect(doc.at_css(".ba-community-tile .ba-status").text.strip).to eq "参加中"
    expect(response.body).not_to include("承認待ちの会", "未参加の会", "停止中の会", "音楽の会")
  end

  it "承認されると一覧に加わり、ホームの状態も参加中になる" do
    Business::Memberships::ApproveCommunityRequest.call(community: pending, customer_id: viewer.id)

    get business_communities_path
    expect(tile_names).to contain_exactly("参加済みの会", "承認待ちの会")

    get business_root_path
    expect(home_items["承認待ちの会"]).to eq "参加中"
  end

  it "ページ送りは参加済みの集合だけを対象にする(未参加がページを埋めない)" do
    others = Array.new(5) { |i| business_community("追加参加#{i}").tap { |c| CommunityCustomer.create!(community: c, customer: viewer) } }
    Array.new(3) { |i| business_community("追加未参加#{i}") }

    get business_communities_path
    page1 = tile_names
    get business_communities_path(page: 2)
    page2 = tile_names

    expect(page1.size).to eq 5
    expect(page2.size).to eq 1
    expect(page1 + page2).to match_array(([joined] + others).map(&:name))
    expect(doc.at_css(".pagination")).to be_present
  end

  it "参加先が0件なら「参加中のコミュニティはありません」とホームへの導線を出す" do
    CommunityCustomer.where(customer: viewer).delete_all

    get business_communities_path

    expect(tile_names).to be_empty
    expect(doc.at_css(".ba-empty").text).to include("参加中のコミュニティはありません")
    expect(doc.at_css(%(.ba-empty a[href="#{business_root_path(anchor: "my-communities")}"]))).to be_present
  end

  it "ホームから未参加のコミュニティを開くと既存の参加案内があり、参加すると一覧に出る" do
    get business_community_path(unjoined)

    expect(response).to have_http_status(:ok)
    expect(doc.at_css("#community-join a").text.strip).to eq "参加する"
    expect(doc.at_css("[data-share-url]")["value"]).to end_with "/business/communities/#{unjoined.id}"

    post business_community_permit_path(unjoined)
    expect(viewer.community_customers.exists?(community_id: unjoined.id)).to be true

    get business_communities_path
    expect(tile_names).to include("未参加の会")
  end

  it "承認制の未参加コミュニティは、詳細から参加を申請でき、申請中は一覧に出ない" do
    manual = business_community("申請前の会", mode: :manual)

    get business_community_path(manual)
    expect(doc.at_css("#community-join a").text.strip).to eq "参加を申請する"

    post business_community_permit_path(manual)
    expect(viewer.permits.exists?(community_id: manual.id)).to be true

    get business_communities_path
    expect(tile_names).not_to include("申請前の会")
    get business_root_path
    expect(home_items["申請前の会"]).to eq "承認待ち"
  end
end
