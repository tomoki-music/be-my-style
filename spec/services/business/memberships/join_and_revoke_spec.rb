require "rails_helper"

RSpec.describe "Business::Memberships" do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "企画") }
  let(:customer) { create(:customer, domain_name: "business") }

  describe Business::Memberships::JoinCommunity do
    it "手動承認では何度呼んでも承認待ちは1件" do
      results = Array.new(3) { described_class.call(community: community, customer: customer) }

      expect(results).to eq %i[requested already_requested already_requested]
      expect(Permit.where(community: community, customer: customer).count).to eq 1
    end

    it "自動承認では何度呼んでも参加は1件" do
      community.update!(join_approval_mode: :auto)

      results = Array.new(3) { described_class.call(community: community, customer: customer) }

      expect(results).to eq %i[joined already_member already_member]
      expect(CommunityCustomer.where(community: community, customer: customer).count).to eq 1
    end

    it "退会済み会員・music のコミュニティは参加できない" do
      expect(described_class.call(community: community, customer: create(:customer, is_deleted: true))).to eq :unavailable
      expect(described_class.call(community: create(:community, owner: owner), customer: customer)).to eq :unavailable
    end

    it "アクセス停止中は自動承認でも参加できない" do
      community.update!(join_approval_mode: :auto)
      CommunityAccessSuspension.create!(community: community, customer: customer)

      expect(described_class.call(community: community, customer: customer)).to eq :suspended
      expect(CommunityCustomer.where(community: community, customer: customer)).to be_empty
    end
  end

  describe Business::Memberships::RevokeCommunityAccess do
    before do
      CommunityCustomer.create!(community: community, customer: customer)
      ProjectMember.create!(project: project, customer: customer)
    end

    it "参加・承認待ち・配下プロジェクトの参加と申請を外し、停止を記録する(2回呼んでも1件)" do
      other = Project.create!(community: community, customer: owner, title: "別企画")
      ProjectJoinRequest.create!(project: other, customer: customer)
      unrelated = Project.create!(community: create(:community, owner: owner, domain: business_domain), customer: owner, title: "他コミュニティ")
      ProjectMember.create!(project: unrelated, customer: customer)

      2.times { described_class.call(community: community, customer: customer, suspend: true, actor: owner) }

      expect(CommunityCustomer.where(community: community, customer: customer)).to be_empty
      expect(ProjectMember.where(customer: customer).pluck(:project_id)).to eq [unrelated.id]
      expect(ProjectJoinRequest.where(customer: customer)).to be_empty
      expect(CommunityAccessSuspension.where(community: community, customer: customer).count).to eq 1
      expect(CommunityAccessSuspension.last.suspended_by).to eq owner
    end
  end

  describe Business::Memberships::JoinProject do
    before { CommunityCustomer.create!(community: community, customer: customer) }

    it "手動承認では申請1件、自動承認では参加1件" do
      expect(Array.new(2) { described_class.call(project: project, customer: customer) }).to eq %i[requested already_requested]

      auto = Project.create!(community: community, customer: owner, title: "自動", join_approval_mode: :auto)
      expect(Array.new(2) { described_class.call(project: auto, customer: customer) }).to eq %i[joined already_member]
      expect(ProjectMember.where(project: auto, customer: customer).count).to eq 1
    end

    it "募集終了後は参加・申請できない" do
      project.update!(deadline: 1.day.ago)

      expect(described_class.call(project: project, customer: customer)).to eq :closed
    end

    it "同時に挿入されても DB の一意制約で重複しない" do
      ProjectJoinRequest.create!(project: project, customer: customer)
      duplicate = ProjectJoinRequest.new(project: project, customer: customer)

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
