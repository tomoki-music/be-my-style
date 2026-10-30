require "rails_helper"

# Business の画面には音楽コミュニティの名称・件数・リンクを出さない(音楽と両方の利用者でも)。
# 音楽側のホーム(/)と所属データはそのまま。
RSpec.describe "Business の画面と音楽コミュニティの分離", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let!(:music_domain) { Domain.find_or_create_by!(name: "music") }

  let(:owner) { create(:customer, domain_name: "business", onboarding_done: true) }
  let(:viewer) do
    create(:customer, domain_name: "music", onboarding_done: true).tap do |customer|
      CustomerDomain.create!(customer: customer, domain: business_domain)
    end
  end

  def community!(name, domain:, **attrs)
    Community.create!(name: name, introduction: "#{name}の紹介", owner: owner, domain: domain,
                      required_plan_for_event_creation: "premium", **attrs)
  end

  let!(:music_club) { community!("駅前ジャズセッション", domain: music_domain) }
  let!(:music_pending) { community!("週末アコースティック部", domain: music_domain) }
  let!(:design_club) { community!("デザイン勉強会", domain: business_domain) }

  before do
    CommunityCustomer.create!(community: music_club, customer: viewer)
    Permit.create!(community: music_pending, customer: viewer)
    CommunityCustomer.create!(community: design_club, customer: viewer)
    sign_in viewer
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def music_link_selector
    %(a[href^="/public"], a[href="/"])
  end

  it "Business ホームは Business コミュニティだけを数え、音楽コミュニティの名称・バッジ・イベント導線を出さない" do
    get business_root_path

    section = doc.at_css("#my-communities")
    expect(section.css(".ba-circle-item__name").map(&:text)).to eq ["デザイン勉強会"]
    expect(section.at_css(".ba-count").text).to eq "1件"
    expect(response.body).not_to include("駅前ジャズセッション", "週末アコースティック部", "音楽コミュニティを探す", "イベントを見る")
    expect(section.at_css(%(a[href="#{business_communities_path}"])).text.strip).to eq "コミュニティを探す"
  end

  it "Business ホームのページ分割も Business コミュニティだけで数える(音楽コミュニティでページが埋まらない)" do
    6.times { |i| CommunityCustomer.create!(community: community!("音楽#{i}", domain: music_domain), customer: viewer) }

    get business_root_path

    expect(doc.css("#my-communities .ba-circle-item__name").map(&:text)).to eq ["デザイン勉強会"]
    expect(doc.at_css("#my-communities .pagination")).to be_nil
  end

  it "Business の主要画面(ホーム・一覧・プロフィール・通知)に音楽側へのリンクを出さない" do
    [
      business_root_path,
      business_communities_path,
      business_projects_path,
      business_customer_path(viewer),
      edit_business_customer_path(viewer),
      business_community_path(design_club)
    ].each do |path|
      get path
      expect(response).to have_http_status(:ok), path
      expect(doc.css(music_link_selector).map { |a| a["href"] }).to eq([]), path
      expect(response.body).not_to include("駅前ジャズセッション")
    end
  end

  it "Business のコミュニティ一覧に音楽コミュニティを出さない" do
    get business_communities_path

    expect(doc.css(".ba-community-tile__name").map(&:text)).to eq ["デザイン勉強会"]
  end

  it "Business のプロフィールの参加コミュニティは Business のものだけ(他人のプロフィールでも)" do
    get business_customer_path(viewer)
    expect(doc.css(".ba-chip").map(&:text)).to eq ["デザイン勉強会"]

    sign_in owner
    get business_customer_path(viewer)
    expect(doc.css(".ba-chip").map(&:text)).to eq ["デザイン勉強会"]
  end

  it "音楽側のホーム(/)と所属データは変わらない" do
    expect { get business_root_path }.not_to(change { [viewer.community_customers.count, viewer.permits.count] })

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("駅前ジャズセッション", "週末アコースティック部")
  end
end
