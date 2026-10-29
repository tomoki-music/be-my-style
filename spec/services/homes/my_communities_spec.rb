require "rails_helper"

RSpec.describe Homes::MyCommunities do
  let(:music_domain) { Domain.find_or_create_by!(name: "music") }
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:other_owner) { create(:customer) }
  let(:viewer) { create(:customer) }

  before { CustomerDomain.create!(customer: viewer, domain: business_domain) }

  def community!(name, domain:, owner: other_owner, updated_at: Time.current)
    create(:community, name: name, domain: domain, owner: owner).tap { |c| c.update_columns(updated_at: updated_at) }
  end

  def result(page: nil)
    described_class.call(viewer, page: page)
  end

  it "参加済み・運営(owner_id / CommunityOwner)・承認待ちだけを、更新が新しい順に重複なく返す" do
    joined = community!("参加", domain: music_domain, updated_at: 1.minute.ago)
    CommunityCustomer.create!(community: joined, customer: viewer)
    owned = community!("主宰", domain: business_domain, owner: viewer, updated_at: 2.minutes.ago)
    CommunityCustomer.create!(community: owned, customer: viewer)
    co_owned = community!("共同運営", domain: business_domain, updated_at: 3.minutes.ago)
    CommunityOwner.create!(community: co_owned, customer: viewer)
    pending = community!("申請中", domain: business_domain, updated_at: 4.minutes.ago)
    Permit.create!(community: pending, customer: viewer)
    community!("無関係", domain: business_domain, updated_at: Time.current)

    res = result

    expect(res.communities.map(&:name)).to eq %w[参加 主宰 共同運営 申請中]
    expect(res.communities.total_count).to eq 4
    expect(res.statuses).to eq(joined.id => :member, owned.id => :manager, co_owned.id => :manager, pending.id => :pending)
  end

  it "退出・アクセス停止で参加行が消えたコミュニティは出さない" do
    community = community!("停止された", domain: business_domain)
    CommunityCustomer.create!(community: community, customer: viewer)
    Business::Memberships::RevokeCommunityAccess.call(community: community, customer: viewer, suspend: true, actor: other_owner)

    expect(result.communities).to be_empty
  end

  it "音楽ドメイン未登録なら音楽コミュニティを出さない(リンク先で弾かれるため)" do
    business_only = create(:customer, domain_name: "business")
    music = community!("音楽", domain: music_domain)
    CommunityCustomer.create!(community: music, customer: business_only)

    expect(described_class.call(business_only).communities).to be_empty
  end

  it "管理者でも関係の無いコミュニティは出さず、関係のあるものは運営として扱う" do
    viewer.update!(is_owner: :admin)
    joined = community!("参加", domain: music_domain)
    CommunityCustomer.create!(community: joined, customer: viewer)
    community!("無関係", domain: music_domain)

    expect(result.communities.map(&:name)).to eq %w[参加]
    expect(result.statuses).to eq(joined.id => :manager)
  end

  it "6件ずつページ分割する" do
    7.times do |i|
      CommunityCustomer.create!(community: community!("c#{i}", domain: music_domain, updated_at: i.minutes.ago), customer: viewer)
    end

    expect(result.communities.size).to eq 6
    expect(result(page: 2).communities.map(&:name)).to eq %w[c6]
    expect(result(page: 2).communities.total_count).to eq 7
  end
end
