require "rails_helper"

RSpec.describe Homes::MyProjects do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:viewer) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "企画コミュニティ") }

  def project!(title, community: self.community, customer: owner, updated_at: Time.current)
    Project.create!(community: community, customer: customer, title: title).tap { |p| p.update_columns(updated_at: updated_at) }
  end

  def result(customer = viewer, page: nil)
    described_class.call(customer, page: page)
  end

  context "コミュニティ参加者" do
    before { CommunityCustomer.create!(community: community, customer: viewer) }

    it "主催・参加中・承認待ちだけを返し、参加していないプロジェクトは出さない" do
      hosted = project!("主催", customer: viewer, updated_at: 1.minute.ago)
      joined = project!("参加", updated_at: 2.minutes.ago).tap { |p| ProjectMember.create!(project: p, customer: viewer) }
      pending = project!("申請中", updated_at: 3.minutes.ago).tap { |p| ProjectJoinRequest.create!(project: p, customer: viewer) }
      project!("未参加", updated_at: Time.current)

      res = result

      expect(res.projects.map(&:title)).to eq %w[主催 参加 申請中]
      expect(res.statuses).to eq(hosted.id => :owner, joined.id => :member, pending.id => :pending)
    end

    it "主催かつ参加者でも1件として返す" do
      ProjectMember.create!(project: project!("主催", customer: viewer), customer: viewer)

      expect(result.projects.total_count).to eq 1
    end

    it "6件ずつページ分割する" do
      7.times { |i| ProjectMember.create!(project: project!("p#{i}", updated_at: i.minutes.ago), customer: viewer) }

      expect(result.projects.size).to eq 6
      expect(result(page: 2).projects.map(&:title)).to eq %w[p6]
    end
  end

  it "親コミュニティの参加資格を失うと、参加していたプロジェクトも出さない" do
    CommunityCustomer.create!(community: community, customer: viewer)
    ProjectMember.create!(project: project!("参加"), customer: viewer)
    Business::Memberships::RevokeCommunityAccess.call(community: community, customer: viewer)

    expect(result.projects).to be_empty
  end

  it "コミュニティに参加していない人の主催・参加行(旧データ)は出さない" do
    ProjectMember.create!(project: project!("旧データ", customer: viewer), customer: viewer)

    expect(result.projects).to be_empty
  end

  it "プロジェクトのアクセス停止で参加行が消えると出さない" do
    CommunityCustomer.create!(community: community, customer: viewer)
    project = project!("停止")
    ProjectMember.create!(project: project, customer: viewer)
    Business::Memberships::RevokeProjectAccess.call(project: project, customer: viewer, suspend: true, actor: owner)

    expect(result.projects).to be_empty
  end

  it "コミュニティ運営者には配下の全プロジェクトを管理として返す" do
    co_owner = create(:customer, domain_name: "business")
    CommunityOwner.create!(community: community, customer: co_owner)
    first = project!("A", updated_at: 1.minute.ago)
    second = project!("B", updated_at: 2.minutes.ago)

    expect(result(owner).statuses).to eq(first.id => :manager, second.id => :manager)
    expect(result(co_owner).projects.map(&:title)).to eq %w[A B]
  end

  it "管理者でも関係の無いコミュニティのプロジェクトは出さない" do
    admin = create(:customer, domain_name: "business", is_owner: :admin)
    project!("他人の企画")

    expect(result(admin).projects).to be_empty
  end

  it "音楽コミュニティに紐づくプロジェクトは出さない" do
    music_community = create(:community, owner: viewer)
    CommunityCustomer.create!(community: music_community, customer: viewer)
    project!("音楽側", community: music_community, customer: viewer)

    expect(result.projects).to be_empty
  end

  describe "プライベート(参加済みの本人だけ)" do
    def private_project!(title, updated_at: Time.current)
      Project.create!(community: community, customer: owner, title: title, visibility: :private).tap { |p| p.update_columns(updated_at: updated_at) }
    end

    it "親コミュニティに所属していなくても、参加済みなら参加中として返す" do
      secret = private_project!("ひみつ")
      ProjectMember.create!(project: secret, customer: viewer)

      expect(result.projects.map(&:title)).to eq %w[ひみつ]
      expect(result.statuses).to eq(secret.id => :member)
    end

    it "参加していない人には、運営者・システム管理者でも返さない" do
      private_project!("ひみつ")
      admin = create(:customer, domain_name: "business", is_owner: :admin)
      CommunityCustomer.create!(community: community, customer: viewer)

      expect(result.projects).to be_empty
      expect(result(owner).projects).to be_empty
      expect(result(admin).projects).to be_empty
    end

    it "件数とページ送りにも同じ条件を使う(参加者は 7 件で 2 ページ目に 1 件、未参加者は 6 件で 1 ページ)" do
      member = create(:customer, domain_name: "business")
      [viewer, member].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
      6.times do |i|
        project = project!("p#{i}", updated_at: (i + 1).minutes.ago)
        [viewer, member].each { |customer| ProjectMember.create!(project: project, customer: customer) }
      end
      ProjectMember.create!(project: private_project!("ひみつ", updated_at: 10.minutes.ago), customer: member)

      expect(result(member).projects.total_count).to eq 7
      expect(result(member, page: 2).projects.map(&:title)).to eq %w[ひみつ]
      expect(result(viewer).projects.total_count).to eq 6
      expect(result(viewer).projects.total_pages).to eq 1
      expect(result(viewer, page: 2).projects).to be_empty
    end

    it "退出・アクセス停止・親コミュニティのアクセス停止の後は返さない" do
      secret = private_project!("ひみつ")
      ProjectMember.create!(project: secret, customer: viewer)
      Business::Memberships::RevokeProjectAccess.call(project: secret, customer: viewer)
      expect(result.projects).to be_empty

      ProjectMember.create!(project: secret, customer: viewer)
      ProjectAccessSuspension.create!(project: secret, customer: viewer, suspended_by: owner)
      expect(result.projects).to be_empty

      ProjectAccessSuspension.delete_all
      CommunityAccessSuspension.create!(community: community, customer: viewer, suspended_by: owner)
      expect(result.projects).to be_empty
    end

    it "限定公開は参加していても返さない(従来どおり)" do
      CommunityCustomer.create!(community: community, customer: viewer)
      unlisted = Project.create!(community: community, customer: owner, title: "限定", visibility: :unlisted)
      ProjectMember.create!(project: unlisted, customer: viewer)

      expect(result.projects).to be_empty
    end
  end
end
