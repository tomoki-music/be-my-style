require "rails_helper"

RSpec.describe "Business::Memberships の参加状況" do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:viewer) { create(:customer, domain_name: "business") }

  def community!(name)
    Community.create!(name: name, introduction: "紹介", owner: owner, domain: business_domain, required_plan_for_event_creation: "premium")
  end

  describe Business::Memberships::CommunityStatuses do
    it "運営 > 管理権限 > 参加中 > 停止中 > 承認待ち > 未参加 の順に決める" do
      operated = community!("運営").tap { |c| c.update!(owner: viewer) }
      sub_owned = community!("運営権限").tap { |c| CommunityOwner.create!(community: c, customer: viewer) }
      joined = community!("参加").tap { |c| CommunityCustomer.create!(community: c, customer: viewer) }
      suspended = community!("停止").tap { |c| CommunityAccessSuspension.create!(community: c, customer: viewer) }
      pending = community!("申請").tap { |c| Permit.create!(community: c, customer: viewer) }
      none = community!("未参加")

      statuses = described_class.call(customer: viewer, communities: [operated, sub_owned, joined, suspended, pending, none])

      expect(statuses.values).to eq %i[operator operator member suspended pending none]
      viewer.update!(is_owner: :admin)
      expect(described_class.for(customer: viewer, community: joined)).to eq :admin
      expect(described_class.for(customer: viewer, community: operated)).to eq :operator
    end

    it "件数によらず一定回数の問い合わせで求める" do
      communities = Array.new(5) { |i| community!("c#{i}") }
      viewer.reload
      queries = 0
      counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        described_class.call(customer: viewer, communities: communities)
      end

      expect(queries).to be <= 4
    end
  end

  describe Business::Memberships::ProjectStatuses do
    let(:community) { community!("親").tap { |c| CommunityCustomer.create!(community: c, customer: owner) } }

    def project!(title, customer: owner, **attrs)
      Project.create!(community: community, customer: customer, title: title, description: "説明", **attrs)
    end

    it "運営・主催・管理権限・参加中・停止中・承認待ち・募集終了・未参加を見分ける" do
      CommunityCustomer.create!(community: community, customer: viewer)
      own = project!("主催", customer: viewer)
      joined = project!("参加").tap { |p| ProjectMember.create!(project: p, customer: viewer) }
      suspended = project!("停止").tap { |p| ProjectAccessSuspension.create!(project: p, customer: viewer) }
      pending = project!("申請").tap { |p| ProjectJoinRequest.create!(project: p, customer: viewer) }
      closed = project!("終了").tap { |p| p.update_columns(deadline: 1.day.ago) }
      none = project!("未参加")

      expect(described_class.call(customer: viewer, projects: [own, joined, suspended, pending, closed, none]).values)
        .to eq %i[owner member suspended pending closed none]
      expect(described_class.for(customer: owner, project: none)).to eq :operator
    end

    it "親コミュニティを抜けたプロジェクト参加者・作成者は参加中・主催にしない" do
      own = project!("主催", customer: viewer)
      joined = project!("参加").tap { |p| ProjectMember.create!(project: p, customer: viewer) }

      expect(described_class.call(customer: viewer, projects: [own, joined]).values).to eq %i[none none]
    end
  end
end
