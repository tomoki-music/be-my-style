require "rails_helper"

RSpec.describe "script/business_access_preflight.rb" do
  before(:all) { load Rails.root.join("script/business_access_preflight.rb") }

  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "企画") }

  def project_member(**attributes)
    create(:customer, domain_name: "business", **attributes).tap do |customer|
      ProjectMember.create!(project: project, customer: customer)
    end
  end

  def report
    BusinessAccessPreflight.run.join("\n")
  end

  it "コミュニティ参加資格の無いプロジェクト参加者を、承認してはいけないケースごとに数える" do
    CommunityCustomer.create!(community: community, customer: project_member)
    project_member(is_deleted: true)
    Permit.create!(community: community, customer: project_member)
    project_member
    # 停止時には配下プロジェクトの行も消すため、通常は残らない(旧コードで作られた行などを想定)。
    CommunityAccessSuspension.create!(community: community, customer: project_member, suspended_by: owner)
    co_owner = project_member
    CommunityOwner.create!(community: community, customer: co_owner)

    output = report

    expect(output).to include("rows=4 communities=1 projects=1 customers=4")
    expect(output).to include("withdrawn: rows=1 customers=1")
    expect(output).to include("permit_pending: rows=1 customers=1")
    expect(output).to include("not_in_community: rows=1 customers=1")
    expect(output).to include("community_suspended: rows=1 customers=1")
  end

  it "コミュニティ参加資格の無いプロジェクト作成者を数え、DETAIL では ID だけを出す" do
    creator = create(:customer, domain_name: "business", name: "作成者の氏名")
    Project.create!(community: community, customer: creator, title: "旧データ")

    output = BusinessAccessPreflight.run(detail: true).join("\n")

    expect(output).to match(/プロジェクト作成者.*\n  rows=1 communities=1 projects=1 customers=1/)
    expect(output).to include("customer_id=#{creator.id} category=not_in_community")
    expect(output).not_to include("作成者の氏名")
    expect(output).not_to include(creator.email)
  end

  it "切り替え後は、全体トークの無いプロジェクトと未所属の投稿をプロジェクト ID 付きで検出する" do
    legacy = Project.create!(community: community, customer: owner, title: "旧コードで作成")
    legacy.project_threads.delete_all
    chat = ProjectChat.create!(project: project, customer: owner, body: "旧コードの投稿")
    chat.update_column(:project_thread_id, nil)

    output = report

    expect(output).to include("unthreaded_project_chats=1 projects_with_unthreaded_chats=1 business_projects_without_general_thread=1")
    expect(output).to include("unthreaded project_ids=#{project.id}")
    expect(output).to include("without_general_thread project_ids=#{legacy.id}")
  end

  it "DB を更新しない" do
    project_member
    expect {
      report
    }.not_to(change { [ProjectMember.count, CommunityCustomer.count, Permit.count, ProjectThread.count] })
  end
end
