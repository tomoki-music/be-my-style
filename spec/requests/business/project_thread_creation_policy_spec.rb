require "rails_helper"

# プロジェクトごとの「スレッドを作成できる人」(Project#thread_creation_policy)。
# 作成ボタンの表示・作成フォーム・作成処理が同じ判定(BusinessAccess#can_create_project_thread?)で揃うこと、
# 設定を変えられるのがシステム管理者と親コミュニティのオーナー本人だけであること、
# 既存スレッドの閲覧・返信は設定に関係なく従来の権限(プロジェクトの参加者)のままであることを確かめる。
RSpec.describe "Business スレッドを作成できる人", type: :request do
  let!(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business", name: "オーナー本人", onboarding_done: true) }
  let(:community) { create(:community, owner: owner, domain: business_domain, name: "作成権限コミュニティ") }
  let(:admin) { create(:customer, domain_name: "business", name: "システム管理者", is_owner: :admin, onboarding_done: true) }
  let(:co_manager) { create(:customer, domain_name: "business", name: "共同運営者", onboarding_done: true) }
  let(:creator) { create(:customer, domain_name: "business", name: "プロジェクト作成者", onboarding_done: true) }
  let(:member) { create(:customer, domain_name: "business", name: "承認済みメンバー", onboarding_done: true) }
  let(:pending) { create(:customer, domain_name: "business", name: "承認待ちさん", onboarding_done: true) }
  let(:non_project) { create(:customer, domain_name: "business", name: "プロジェクト未参加さん", onboarding_done: true) }
  let(:outsider) { create(:customer, domain_name: "business", name: "コミュニティ外さん", onboarding_done: true) }
  let(:suspended) { create(:customer, domain_name: "business", name: "停止中さん", onboarding_done: true) }
  let(:community_suspended) { create(:customer, domain_name: "business", name: "コミュニティ停止中さん", onboarding_done: true) }
  let!(:project) { Project.create!(community: community, customer: creator, title: "スレッド権限の企画") }
  let!(:existing_thread) { project.project_threads.first }

  before do
    [owner, co_manager, creator, member, pending, non_project, suspended, community_suspended].each do |customer|
      CommunityCustomer.create!(community: community, customer: customer)
    end
    CommunityOwner.create!(community: community, customer: co_manager)
    [member, suspended, community_suspended].each { |customer| ProjectMember.create!(project: project, customer: customer) }
    ProjectJoinRequest.create!(project: project, customer: pending)
    Business::Memberships::RevokeProjectAccess.call(project: project, customer: suspended, suspend: true, actor: owner)
    Business::Memberships::RevokeCommunityAccess.call(community: community, customer: community_suspended, suspend: true, actor: owner)
  end

  def doc
    Nokogiri::HTML(response.body)
  end

  def new_thread_links
    doc.css(%(a[href="#{new_business_project_thread_path(project)}"]))
  end

  def create_thread(title = "新しい話題")
    post business_project_threads_path(project), params: { project_thread: { title: title, description: "説明" } }
  end

  def roles
    {
      admin: admin, owner: owner, co_manager: co_manager, creator: creator, member: member,
      pending: pending, non_project: non_project, outsider: outsider, suspended: suspended,
      community_suspended: community_suspended
    }
  end

  # 各設定で作成できる役割。ここに無い役割は、ボタンが出ず・フォームも作成も拒否される。
  EXPECTED_CREATORS = {
    "owners_only" => %i[admin owner],
    "managers" => %i[admin owner co_manager creator],
    "all_members" => %i[admin owner co_manager creator member]
  }.freeze

  # 内部(スレッド一覧・既存スレッド)を閲覧できる役割。設定に関係なく従来どおり。
  PARTICIPANTS = %i[admin owner co_manager creator member].freeze

  describe "初期値" do
    it "既存・新規のプロジェクトは「管理者・オーナーのみ」" do
      expect(Project.new.thread_creation_policy).to eq "owners_only"
      expect(project.reload).to be_thread_creation_owners_only
    end
  end

  EXPECTED_CREATORS.each do |policy, allowed|
    describe "設定「#{policy}」" do
      before { project.update!(thread_creation_policy: policy) }

      it "役割ごとに、判定・ボタン表示・作成フォーム・作成処理が一致する" do
        roles.each do |role, customer|
          can_create = allowed.include?(role)
          expect(customer.can_create_project_thread?(project)).to eq(can_create), "#{role} の判定"

          sign_in customer

          get business_project_path(project)
          expect(new_thread_links.size).to eq(can_create ? 1 : 0), "#{role} のプロジェクト画面のボタン"

          get business_project_threads_path(project)
          if PARTICIPANTS.include?(role)
            expect(response).to have_http_status(:ok), "#{role} のスレッド一覧"
            expect(new_thread_links.size).to eq(can_create ? 1 : 0), "#{role} のスレッド一覧のボタン"
          else
            expect(response).to have_http_status(:redirect), "#{role} のスレッド一覧"
          end

          get new_business_project_thread_path(project)
          if can_create
            expect(response).to have_http_status(:ok), "#{role} の作成フォーム"
          else
            expect(response).to have_http_status(:redirect), "#{role} の作成フォーム"
          end

          title = "#{role}の話題"
          expect { create_thread(title) }.to change(ProjectThread, :count).by(can_create ? 1 : 0), "#{role} の作成処理"
          if can_create
            created = project.project_threads.find_by!(title: title)
            expect(created.customer).to eq customer
            expect(response).to redirect_to(business_project_thread_path(project, created))
          else
            expect(response).to have_http_status(:redirect)
            expect(project.project_threads.where(title: title)).to be_empty
          end

          sign_out customer
        end
      end

      it "権限外の参加者が直接リクエストすると、スレッド一覧へ戻して理由を伝える" do
        denied = (PARTICIPANTS - allowed).map { |role| roles.fetch(role) }
        denied.each do |customer|
          sign_in customer

          get new_business_project_thread_path(project)
          expect(response).to redirect_to(business_project_threads_path(project))
          expect(flash[:alert]).to eq "このプロジェクトでスレッドを作成する権限がありません。"

          expect { create_thread }.not_to change(ProjectThread, :count)
          expect(response).to redirect_to(business_project_threads_path(project))

          sign_out customer
        end
      end

      it "既存スレッドの閲覧・返信は、設定に関係なくプロジェクトの参加者ができ、参加者以外はできない" do
        roles.each do |role, customer|
          sign_in customer
          body = "#{role}からの返信"

          get business_project_thread_path(project, existing_thread)
          expect {
            post business_project_thread_project_chats_path(project, existing_thread), params: { project_chat: { body: body } }
          }.to change(ProjectChat, :count).by(PARTICIPANTS.include?(role) ? 1 : 0), "#{role} の返信"
          expect(existing_thread.project_chats.where(body: body).exists?).to eq(PARTICIPANTS.include?(role))

          sign_out customer
        end
      end
    end
  end

  describe "アクセス停止の記録" do
    it "停止の記録があれば、参加の行が残っていても(移行途中などの旧データ)メンバー枠では作成できない" do
      project.update!(thread_creation_policy: :all_members)
      leftover = create(:customer, domain_name: "business", name: "行が残った停止中さん", onboarding_done: true)
      CommunityCustomer.create!(community: community, customer: leftover)
      ProjectMember.create!(project: project, customer: leftover)
      expect(leftover.can_create_project_thread?(project)).to be true

      ProjectAccessSuspension.create!(project: project, customer: leftover, suspended_by: owner)
      expect(leftover.can_create_project_thread?(project)).to be false

      ProjectAccessSuspension.where(customer: leftover).destroy_all
      CommunityAccessSuspension.create!(community: community, customer: leftover, suspended_by: owner)
      expect(leftover.can_create_project_thread?(project)).to be false
    end
  end

  describe "設定の変更" do
    def update_policy(value, title: project.title)
      patch business_project_path(project), params: { project: { title: title, thread_creation_policy: value } }
    end

    it "システム管理者と親コミュニティのオーナー本人は、編集画面で選べて保存できる" do
      [owner, admin].each do |customer|
        sign_in customer
        get edit_business_project_path(project)
        select = doc.at_css("select[name='project[thread_creation_policy]']")
        expect(select).to be_present
        expect(select.css("option").map { |option| [option.text, option["value"]] }).to eq [
          ["管理者・オーナーのみ", "owners_only"], ["運営者まで", "managers"], ["参加メンバー全員", "all_members"]
        ]
        expect(select.at_css("option[selected]")["value"]).to eq project.reload.thread_creation_policy

        update_policy("managers")
        expect(response).to redirect_to(business_project_path(project))
        expect(project.reload).to be_thread_creation_managers

        update_policy("owners_only")
        expect(project.reload).to be_thread_creation_owners_only
        sign_out customer
      end
    end

    it "運営者・プロジェクト作成者は編集できても設定は変えられず、現在の設定だけが表示される" do
      project.update!(thread_creation_policy: :managers)

      [co_manager, creator].each do |customer|
        sign_in customer
        get edit_business_project_path(project)
        expect(doc.at_css("select[name='project[thread_creation_policy]']")).to be_nil
        expect(doc.at_css("#project-thread-creation .ba-static").text.strip).to eq "運営者まで"

        update_policy("all_members", title: "#{customer.name}が改名")
        expect(response).to redirect_to(business_project_path(project))
        project.reload
        expect(project.title).to eq "#{customer.name}が改名"
        expect(project).to be_thread_creation_managers
        sign_out customer
      end
    end

    it "編集画面を開けない人(一般メンバー)の送信は拒否され、設定は変わらない" do
      sign_in member
      update_policy("all_members")
      expect(response).to have_http_status(:redirect)
      expect(project.reload).to be_thread_creation_owners_only
    end

    it "選択肢にない値は受け付けず、保存済みの設定を残す" do
      sign_in owner
      update_policy("everyone")
      expect(project.reload).to be_thread_creation_owners_only
    end

    it "新規作成時に送っても無視し、管理者・オーナーのみで作られる" do
      sign_in owner
      post business_projects_path, params: { project: { community_id: community.id, title: "新規の企画", thread_creation_policy: "all_members" } }
      expect(Project.find_by!(title: "新規の企画")).to be_thread_creation_owners_only
    end

    it "切り替えた直後のリクエストから、メンバーのボタン表示と作成可否に反映される" do
      sign_in owner
      update_policy("all_members")
      sign_out owner

      sign_in member
      get business_project_path(project)
      expect(new_thread_links.size).to eq 1
      expect { create_thread("全員に開放後") }.to change(ProjectThread, :count).by(1)
      sign_out member

      sign_in owner
      update_policy("managers")
      sign_out owner

      sign_in member
      get business_project_path(project)
      expect(new_thread_links).to be_empty
      expect { create_thread("運営者までに戻した後") }.not_to change(ProjectThread, :count)
      sign_out member

      sign_in creator
      expect { create_thread("運営者として作成") }.to change(ProjectThread, :count).by(1)
      sign_out creator

      sign_in admin
      update_policy("owners_only")
      sign_out admin

      sign_in creator
      get business_project_threads_path(project)
      expect(new_thread_links).to be_empty
      expect { create_thread("オーナーのみに戻した後") }.not_to change(ProjectThread, :count)
      # 自分が作ったスレッドへの返信は、作成権限が無くなっても従来どおりできる。
      mine = project.project_threads.find_by!(title: "運営者として作成")
      expect {
        post business_project_thread_project_chats_path(project, mine), params: { project_chat: { body: "続きです" } }
      }.to change(ProjectChat, :count).by(1)
    end
  end
end
