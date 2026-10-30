require "rails_helper"

# Business のコミュニティ・プロジェクトの参加申請(手動 / 自動承認)とアクセス停止。
RSpec.describe "Business の参加申請とアクセス管理", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "A社ホームページ制作") }
  let(:applicant) { create(:customer, domain_name: "business") }

  before { CommunityCustomer.create!(community: community, customer: owner) }

  def join_community
    post business_community_permit_path(community)
  end

  def join_project
    post join_business_project_path(project)
  end

  def can_view_project_internal?
    get business_project_thread_path(project, ProjectThread.default_for(project))
    response.successful?
  end

  describe "初期値" do
    it "新規作成のコミュニティ・プロジェクトは手動承認" do
      expect(community).to be_join_manual
      expect(project).to be_join_manual
    end
  end

  describe "コミュニティ: 手動承認" do
    before { sign_in applicant }

    it "申請すると承認待ちになり、承認されるまで内部コンテンツを閲覧できない" do
      CommunityPost.create!(community: community, customer: owner, body: "内部のお知らせ")

      expect { join_community }.to change(Permit, :count).by(1)
      expect(applicant.business_community_member?(community)).to eq false

      get business_community_path(community)
      expect(response.body).to include("承認待ち")
      expect(response.body).not_to include("内部のお知らせ")

      sign_in owner
      post business_community_community_customers_path(community, customer_id: applicant.id)
      expect(applicant.business_community_member?(community)).to eq true
      expect(Permit.where(community: community, customer: applicant)).to be_empty

      sign_in applicant
      get business_community_path(community)
      expect(response.body).to include("内部のお知らせ")
      expect(response.body).to include("参加中")
    end

    it "連打しても申請は1件だけ" do
      3.times { join_community }

      expect(Permit.where(community: community, customer: applicant).count).to eq 1
      expect(flash[:notice]).to eq "参加申請は承認待ちです"
    end

    it "申請者は承認待ちの申請を取り消せる" do
      join_community

      expect { delete business_community_permit_path(community) }.to change(Permit, :count).by(-1)
    end

    it "却下された後は再申請できる" do
      join_community
      sign_in owner
      delete business_community_permit_path(community, customer_id: applicant.id)
      expect(Permit.where(community: community, customer: applicant)).to be_empty

      sign_in applicant
      expect { join_community }.to change(Permit, :count).by(1)
    end

    it "承認を2回押しても参加は1件だけ" do
      join_community
      sign_in owner

      2.times { post business_community_community_customers_path(community, customer_id: applicant.id) }

      expect(CommunityCustomer.where(community: community, customer: applicant).count).to eq 1
    end
  end

  describe "コミュニティ: 自動承認" do
    before do
      community.update!(join_approval_mode: :auto)
      sign_in applicant
    end

    it "ページを見ただけでは参加扱いにならず、「参加する」を押すと参加済みになる" do
      get business_community_path(community)
      expect(response.body).to include("参加する")
      expect(applicant.business_community_member?(community)).to eq false

      expect { join_community }.to change(CommunityCustomer, :count).by(1)
      expect(Permit.where(community: community, customer: applicant)).to be_empty
      expect(flash[:notice]).to eq "コミュニティに参加しました"
    end

    it "連打しても参加は1件だけ" do
      3.times { join_community }

      expect(CommunityCustomer.where(community: community, customer: applicant).count).to eq 1
    end
  end

  describe "承認方式の変更" do
    it "手動から自動へ変更しても、既存の承認待ちは承認されず、参加済みメンバーもそのまま" do
      member = create(:customer, domain_name: "business")
      CommunityCustomer.create!(community: community, customer: member)
      create(:permit, community: community, customer: applicant)

      sign_in owner
      patch business_community_path(community), params: { community: { join_approval_mode: "auto" } }
      expect(community.reload).to be_join_auto

      expect(applicant.business_community_member?(community)).to eq false
      expect(Permit.where(community: community, customer: applicant)).to exist
      expect(member.business_community_member?(community)).to eq true

      # 承認待ちのまま押しても、勝手に参加済みにはならない(取り消してから参加し直す)。
      sign_in applicant
      join_community
      expect(applicant.business_community_member?(community)).to eq false
      delete business_community_permit_path(community)
      join_community
      expect(applicant.business_community_member?(community)).to eq true
    end

    it "プロジェクトも同様に、変更後の新しい申請から適用する" do
      CommunityCustomer.create!(community: community, customer: applicant)
      ProjectJoinRequest.create!(project: project, customer: applicant)

      sign_in owner
      patch business_project_path(project), params: { project: { join_approval_mode: "auto" } }
      expect(project.reload).to be_join_auto
      expect(applicant.business_project_participant?(project)).to eq false
      expect(ProjectJoinRequest.where(project: project, customer: applicant)).to exist
    end
  end

  describe "権限のないユーザーによる変更" do
    let(:member) { create(:customer, domain_name: "business") }

    before do
      CommunityCustomer.create!(community: community, customer: member)
      ProjectMember.create!(project: project, customer: member)
      create(:permit, community: community, customer: applicant)
      sign_in member
    end

    it "一般参加者は承認方式・申請・所属状態を変更できない" do
      patch business_community_path(community), params: { community: { join_approval_mode: "auto" } }
      expect(community.reload).to be_join_manual

      patch business_project_path(project), params: { project: { join_approval_mode: "auto", title: "乗っ取り" } }
      expect(project.reload).to be_join_manual
      expect(project.title).to eq "A社ホームページ制作"

      post business_community_community_customers_path(community, customer_id: applicant.id)
      expect(applicant.business_community_member?(community)).to eq false

      post business_community_access_suspensions_path(community, customer_id: owner.id)
      post business_community_access_suspensions_path(community, customer_id: applicant.id)
      expect(CommunityAccessSuspension.count).to eq 0

      get business_permits_path(community)
      expect(response).to redirect_to(business_community_path(community))
      get members_business_project_path(project)
      expect(response).to redirect_to(business_project_path(project))

      request = ProjectJoinRequest.create!(project: project, customer: create(:customer).tap { |c| CommunityCustomer.create!(community: community, customer: c) })
      post approve_business_project_join_request_path(project, request)
      expect(ProjectJoinRequest.exists?(request.id)).to eq true
      post business_project_access_suspensions_path(project, customer_id: request.customer_id)
      expect(ProjectAccessSuspension.count).to eq 0
    end

    it "プロジェクトの所属コミュニティをパラメータで変更できない" do
      other_community = create(:community, owner: owner, domain: business_domain)
      sign_in owner

      patch business_project_path(project), params: { project: { community_id: other_community.id, title: "更新" } }

      expect(project.reload.community).to eq community
      expect(project.title).to eq "更新"
    end
  end

  describe "コミュニティのアクセス停止" do
    let(:member) { create(:customer, domain_name: "business") }

    before do
      CommunityCustomer.create!(community: community, customer: member)
      ProjectMember.create!(project: project, customer: member)
      sign_in owner
    end

    it "停止すると配下のプロジェクト・スレッドにも即座にアクセスできなくなり、自動承認でも再参加できない" do
      post business_community_access_suspensions_path(community, customer_id: member.id)
      expect(member.business_community_suspended?(community)).to eq true
      expect(member.business_community_member?(community)).to eq false
      expect(ProjectMember.where(project: project, customer: member)).to be_empty

      community.update!(join_approval_mode: :auto)
      sign_in member
      expect(can_view_project_internal?).to eq false
      get business_community_path(community)
      expect(response.body).to include("アクセス停止中")

      expect { join_community }.not_to change(CommunityCustomer, :count)
      expect(flash[:alert]).to eq "このコミュニティへのアクセスは停止されています"
    end

    it "解除後に再参加しても、過去のプロジェクト参加資格は復活しない" do
      post business_community_access_suspensions_path(community, customer_id: member.id)
      suspension = CommunityAccessSuspension.last
      delete business_community_access_suspension_path(community, suspension)
      expect(member.business_community_suspended?(community)).to eq false
      expect(member.business_community_member?(community)).to eq false

      community.update!(join_approval_mode: :auto)
      sign_in member
      join_community
      expect(member.business_community_member?(community)).to eq true
      expect(member.business_project_participant?(project)).to eq false
      expect(can_view_project_internal?).to eq false
    end

    it "運営者はアクセス停止できない" do
      co_owner = create(:customer, domain_name: "business")
      CommunityOwner.create!(community: community, customer: co_owner)
      CommunityCustomer.create!(community: community, customer: co_owner)

      post business_community_access_suspensions_path(community, customer_id: co_owner.id)

      expect(CommunityAccessSuspension.count).to eq 0
      expect(flash[:alert]).to eq "コミュニティの運営者はアクセス停止できません。"
    end

    it "本人が退会してもプロジェクトの参加資格は外れ、再参加で復活しない" do
      sign_in member
      delete business_community_community_customers_path(community)
      expect(member.business_community_member?(community)).to eq false
      expect(ProjectMember.where(project: project, customer: member)).to be_empty
    end

    it "メンバー管理画面に申請・参加者・停止中を表示する(スマホ幅でも同じ HTML)" do
      create(:permit, community: community, customer: applicant)
      post business_community_access_suspensions_path(community, customer_id: member.id)

      get business_permits_path(community)

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("#join-requests").text).to include(applicant.name)
      expect(html.at_css("#members").text).to include(owner.name)
      expect(html.at_css("#suspensions").text).to include(member.name)
      expect(html.at_css("#members").text).to include("運営者")
    end
  end

  describe "プロジェクトの参加申請" do
    before { sign_in applicant }

    it "親コミュニティに参加していないと申請できない" do
      expect { join_project }.not_to change(ProjectJoinRequest, :count)
      expect(response).to redirect_to(business_community_path(community))
      expect(flash[:alert]).to eq "プロジェクトに参加するには、先にコミュニティへ参加してください"
    end

    it "親コミュニティの承認待ちでもプロジェクトを閲覧・申請できない" do
      create(:permit, community: community, customer: applicant)

      get business_project_path(project)
      expect(response).to redirect_to(business_community_path(community))
      expect { join_project }.not_to change(ProjectJoinRequest, :count)
    end

    context "コミュニティ参加者" do
      before { CommunityCustomer.create!(community: community, customer: applicant) }

      it "手動承認: 申請 → 承認待ち → 承認でスレッドを利用できる" do
        expect { 3.times { join_project } }.to change(ProjectJoinRequest, :count).by(1)
        expect(can_view_project_internal?).to eq false
        get business_project_path(project)
        expect(response.body).to include("承認待ち")

        request = ProjectJoinRequest.last
        sign_in owner
        expect(Notification.where(visited_id: owner.id, action: "project_request")).to exist
        get members_business_project_path(project)
        expect(Nokogiri::HTML(response.body).at_css("#join-requests").text).to include(applicant.name)

        2.times { post approve_business_project_join_request_path(project, request) }
        expect(ProjectMember.where(project: project, customer: applicant).count).to eq 1
        expect(Notification.where(visited_id: applicant.id, action: "project_accept")).to exist

        sign_in applicant
        expect(can_view_project_internal?).to eq true
      end

      it "手動承認: 却下後は再申請でき、本人は申請を取り消せる" do
        join_project
        sign_in owner
        delete reject_business_project_join_request_path(project, ProjectJoinRequest.last)
        expect(ProjectJoinRequest.count).to eq 0

        sign_in applicant
        expect { join_project }.to change(ProjectJoinRequest, :count).by(1)
        expect { delete cancel_request_business_project_path(project) }.to change(ProjectJoinRequest, :count).by(-1)
      end

      it "自動承認: 画面を開いただけでは参加せず、「参加する」で参加できる" do
        project.update!(join_approval_mode: :auto)

        get business_project_path(project)
        expect(response.body).to include("参加する")
        expect(applicant.business_project_participant?(project)).to eq false

        expect { 3.times { join_project } }.to change(ProjectMember, :count).by(1)
        expect(can_view_project_internal?).to eq true
      end

      it "アクセス停止中は自動承認でも参加できない" do
        project.update!(join_approval_mode: :auto)
        ProjectAccessSuspension.create!(project: project, customer: applicant, suspended_by: owner)

        expect { join_project }.not_to change(ProjectMember, :count)
        expect(flash[:alert]).to eq "このプロジェクトへのアクセスは停止されています"
        get business_project_path(project)
        expect(response.body).to include("アクセス停止中")
      end

      it "承認前にコミュニティの参加資格を失った申請は承認しない" do
        join_project
        request = ProjectJoinRequest.last
        CommunityCustomer.where(community: community, customer: applicant).delete_all

        sign_in owner
        post approve_business_project_join_request_path(project, request)

        expect(ProjectMember.where(project: project, customer: applicant)).to be_empty
        expect(ProjectJoinRequest.exists?(request.id)).to eq false
      end
    end
  end

  describe "プロジェクトのアクセス停止" do
    let(:member) { create(:customer, domain_name: "business") }

    before do
      CommunityCustomer.create!(community: community, customer: member)
      ProjectMember.create!(project: project, customer: member)
    end

    it "管理者が停止すると即座にアクセスできなくなり、解除しても再参加が必要" do
      sign_in owner
      post business_project_access_suspensions_path(project, customer_id: member.id)
      expect(member.business_project_participant?(project)).to eq false

      sign_in member
      expect(can_view_project_internal?).to eq false

      sign_in owner
      delete business_project_access_suspension_path(project, ProjectAccessSuspension.last)
      expect(member.business_project_suspended?(project)).to eq false
      expect(member.business_project_participant?(project)).to eq false
    end

    it "プロジェクト作成者・コミュニティ運営者は停止できない" do
      sign_in owner
      post business_project_access_suspensions_path(project, customer_id: owner.id)

      expect(ProjectAccessSuspension.count).to eq 0
    end

    it "別プロジェクトの管理者は停止できない" do
      other_owner = create(:customer, domain_name: "business")
      CommunityCustomer.create!(community: community, customer: other_owner)
      Project.create!(community: community, customer: other_owner, title: "別")
      sign_in other_owner

      post business_project_access_suspensions_path(project, customer_id: member.id)

      expect(ProjectAccessSuspension.count).to eq 0
      expect(member.business_project_participant?(project)).to eq true
    end
  end

  describe "一覧・件数・通知" do
    let(:other_community) { create(:community, owner: owner, domain: business_domain, name: "未参加コミュニティ") }
    let!(:hidden_project) { Project.create!(community: other_community, customer: owner, title: "未参加側の企画") }
    let(:member) { create(:customer, domain_name: "business", onboarding_done: true) }

    before do
      CommunityCustomer.create!(community: community, customer: member)
      project
    end

    it "参加していないコミュニティのプロジェクトは一覧・トップに出ない" do
      sign_in member

      get business_projects_path
      expect(response.body).to include("A社ホームページ制作")
      expect(response.body).not_to include("未参加側の企画")

      get business_root_path
      expect(response.body).not_to include("未参加側の企画")

      get business_projects_path(community_id: other_community.id)
      expect(response).to redirect_to(business_community_path(other_community))
    end

    it "プロジェクトの投稿通知・メールは内部を閲覧できる人だけに届く" do
      participant = create(:customer, domain_name: "business", confirm_mail: true)
      CommunityCustomer.create!(community: community, customer: participant)
      ProjectMember.create!(project: project, customer: participant)
      former = create(:customer, domain_name: "business", confirm_mail: true)
      ProjectMember.create!(project: project, customer: former) # コミュニティ参加資格の無い旧データ
      outsider_pending = create(:customer, domain_name: "business", confirm_mail: true)
      CommunityCustomer.create!(community: community, customer: outsider_pending)
      ProjectJoinRequest.create!(project: project, customer: outsider_pending)

      sign_in participant
      expect {
        post business_project_project_chats_path(project), params: { project_chat: { body: "共有です" } }
      }.to have_enqueued_mail(CustomerMailer, :business_project_chat_mail).at_least(:once)

      notified = Notification.where(action: "project_message", project_id: project.id).pluck(:visited_id)
      expect(notified).to include(owner.id)
      expect(notified).not_to include(former.id, outsider_pending.id, participant.id)
    end
  end

  describe "Business 以外への影響" do
    it "music のコミュニティは Business の参加申請・管理画面から操作できない" do
      music_community = create(:community, owner: owner)
      sign_in applicant

      expect { post business_community_permit_path(music_community) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(Permit.count).to eq 0
    end
  end
end
