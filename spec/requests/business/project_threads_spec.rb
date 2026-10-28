require "rails_helper"

RSpec.describe "Business::ProjectThreads", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "A社ホームページ制作") }
  let(:other_project) { Project.create!(community: community, customer: owner, title: "B社システム開発") }
  let(:member) { create(:customer, domain_name: "business", name: "参加者太郎") }
  let(:other_member) { create(:customer, domain_name: "business", name: "参加者花子") }

  before do
    CommunityCustomer.create!(community: community, customer: owner)
    [member, other_member].each do |customer|
      CommunityCustomer.create!(community: community, customer: customer)
      ProjectMember.create!(project: project, customer: customer)
    end
  end

  def create_thread(title, description: nil)
    post business_project_threads_path(project), params: { project_thread: { title: title, description: description } }
  end

  describe "スレッドの作成と投稿の分離" do
    before { sign_in member }

    it "新規プロジェクトには「全体トーク」があり、参加者は複数のスレッドを作成できる" do
      expect(project.project_threads.pluck(:title)).to eq ["全体トーク"]

      expect { create_thread("デザイン相談", description: "配色やレイアウト") }.to change(ProjectThread, :count).by(1)
      thread = ProjectThread.last
      expect(thread.customer).to eq member
      expect(response).to redirect_to(business_project_thread_path(project, thread))

      expect { create_thread("") }.not_to change(ProjectThread, :count)
      expect(response.body).to include("新しいスレッド")
    end

    it "投稿は対象スレッドに紐づき、ほかのスレッドの投稿と混ざらない" do
      design = project.project_threads.create!(customer: member, title: "デザイン相談")
      dev = project.project_threads.create!(customer: member, title: "開発相談")

      post business_project_thread_project_chats_path(project, design), params: { project_chat: { body: "配色の案です" } }
      post business_project_thread_project_chats_path(project, dev), params: { project_chat: { body: "API の設計です" } }

      expect(design.project_chats.pluck(:body)).to eq ["配色の案です"]
      expect(dev.project_chats.pluck(:body)).to eq ["API の設計です"]

      get business_project_thread_path(project, design)
      expect(response.body).to include("配色の案です")
      expect(response.body).not_to include("API の設計です")
    end

    it "プロジェクト画面とスレッド一覧に、タイトル・説明・投稿数・最終更新日時を新しい順に表示する" do
      old_thread = project.project_threads.create!(customer: member, title: "要件確認", description: "最初の要件", last_posted_at: 2.days.ago)
      ProjectChat.create!(project: project, project_thread: old_thread, customer: member, body: "a")
      recent = project.project_threads.create!(customer: member, title: "不具合報告")
      ProjectChat.create!(project: project, project_thread: recent, customer: member, body: "b")

      get business_project_path(project)
      titles = Nokogiri::HTML(response.body).css(".project-thread-list__title").map(&:text)
      expect(titles.first).to eq "不具合報告"
      expect(titles).to include("要件確認", "全体トーク")
      expect(response.body).to include("最初の要件")
      expect(response.body).to include("最終更新")
      expect(response.body).to include(%(href="#{business_project_thread_path(project, recent)}"))

      get business_project_threads_path(project)
      expect(Nokogiri::HTML(response.body).css(".project-thread-list__item").size).to eq 3
      expect(response.body).to include("💬 1件")
    end

    it "最新の投稿でスレッドの最終更新日時が更新される" do
      thread = project.project_threads.create!(customer: member, title: "相談", last_posted_at: 3.days.ago)

      post business_project_thread_project_chats_path(project, thread), params: { project_chat: { body: "更新" } }

      expect(thread.reload.last_posted_at).to be_within(5.seconds).of(Time.current)
    end
  end

  describe "別プロジェクト・別コミュニティの ID 指定" do
    let(:foreign_thread) { other_project.project_threads.first }

    before { sign_in member }

    it "参加プロジェクトの URL に別プロジェクトのスレッド ID を指定しても閲覧・投稿・編集できない" do
      expect { get business_project_thread_path(project, foreign_thread) }.to raise_error(ActiveRecord::RecordNotFound)

      # 例外で終わったリクエストの後はログイン状態が引き継がれないため、都度ログインし直す。
      sign_in member
      expect {
        expect {
          post business_project_thread_project_chats_path(project, foreign_thread), params: { project_chat: { body: "越境" } }
        }.to raise_error(ActiveRecord::RecordNotFound)
      }.not_to change(ProjectChat, :count)

      sign_in member
      expect {
        patch business_project_thread_path(project, foreign_thread), params: { project_thread: { title: "乗っ取り" } }
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(foreign_thread.reload.title).to eq "全体トーク"
    end

    it "参加していないプロジェクトの URL では閲覧・投稿できない" do
      get business_project_thread_path(other_project, foreign_thread)
      expect(response).to redirect_to(business_project_path(other_project))

      expect {
        post business_project_thread_project_chats_path(other_project, foreign_thread), params: { project_chat: { body: "越境" } }
      }.not_to change(ProjectChat, :count)
    end

    it "別プロジェクトの投稿 ID を指定しても削除できない" do
      foreign_chat = ProjectChat.create!(project: other_project, customer: member, body: "別プロジェクト")
      thread = project.project_threads.first

      expect {
        delete business_project_thread_project_chat_path(project, thread, foreign_chat)
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(ProjectChat.exists?(foreign_chat.id)).to eq true
    end

    it "music のコミュニティのプロジェクトは Business 画面から開けない" do
      music_project = Project.create!(community: create(:community, owner: owner), customer: owner, title: "音楽側")

      expect {
        get business_project_thread_path(music_project, music_project.project_threads.first)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "スレッドの編集・削除権限" do
    let!(:thread) { project.project_threads.create!(customer: member, title: "デザイン相談") }

    it "作成者はタイトル・説明を編集できる" do
      sign_in member

      patch business_project_thread_path(project, thread), params: { project_thread: { title: "デザイン相談（確定）", description: "説明" } }

      expect(thread.reload.title).to eq "デザイン相談（確定）"
    end

    it "作成者以外の参加者は編集できない" do
      sign_in other_member

      patch business_project_thread_path(project, thread), params: { project_thread: { title: "勝手に変更" } }

      expect(thread.reload.title).to eq "デザイン相談"
      expect(flash[:alert]).to eq "このスレッドを編集する権限がありません。"
    end

    it "プロジェクト作成者とコミュニティ運営者は編集できる" do
      co_owner = create(:customer, domain_name: "business")
      CommunityOwner.create!(community: community, customer: co_owner)

      [owner, co_owner].each_with_index do |actor, index|
        sign_in actor
        patch business_project_thread_path(project, thread), params: { project_thread: { title: "管理者変更#{index}" } }
        expect(thread.reload.title).to eq "管理者変更#{index}"
      end
    end

    it "管理者でなければ、スレッド作成者でも(自分の投稿だけのスレッドでも)削除できず、削除ボタンも出ない" do
      ProjectChat.create!(project: project, project_thread: thread, customer: member, body: "自分の投稿")
      empty = project.project_threads.create!(customer: member, title: "投稿なし")
      sign_in member

      get business_project_thread_path(project, thread)
      expect(response.body).to include(edit_business_project_thread_path(project, thread))
      expect(response.body).not_to include('data-method="delete" href="' + business_project_thread_path(project, thread) + '"')

      [thread, empty].each do |target|
        expect { delete business_project_thread_path(project, target) }.not_to change(ProjectThread, :count)
        expect(response).to redirect_to(business_project_thread_path(project, target))
        expect(flash[:alert]).to eq "スレッドはプロジェクトの管理者だけが削除できます。"
      end
      expect(ProjectChat.where(project_thread_id: thread.id).count).to eq 1
    end

    it "プロジェクト作成者はコミュニティ参加資格がある間だけ削除できる" do
      member_project = Project.create!(community: community, customer: member, title: "参加者のプロジェクト")
      first = member_project.project_threads.create!(customer: other_member, title: "他人が作ったスレッド")
      second = member_project.project_threads.create!(customer: other_member, title: "残るスレッド")
      sign_in member

      expect { delete business_project_thread_path(member_project, first) }.to change(ProjectThread, :count).by(-1)

      CommunityCustomer.where(community: community, customer: member).delete_all
      expect { delete business_project_thread_path(member_project, second) }.not_to change(ProjectThread, :count)
    end

    it "管理者はほかの参加者の投稿を含むスレッドも削除できる" do
      ProjectChat.create!(project: project, project_thread: thread, customer: other_member, body: "他人の投稿")
      sign_in owner

      expect { delete business_project_thread_path(project, thread) }.to change(ProjectThread, :count).by(-1)
      expect(ProjectChat.where(project_thread_id: thread.id)).to be_empty
    end

    it "ほかの参加者の投稿は削除できない(投稿の削除は従来どおり本人だけ)" do
      chat = ProjectChat.create!(project: project, project_thread: thread, customer: member, body: "本人の投稿")
      sign_in other_member

      delete business_project_thread_project_chat_path(project, thread, chat)

      expect(ProjectChat.exists?(chat.id)).to eq true
    end
  end

  describe "アクセスできない人" do
    let(:thread) { project.project_threads.first }
    let!(:chat) { ProjectChat.create!(project: project, project_thread: thread, customer: member, body: "内部の相談") }

    def expect_no_internal_access(customer)
      sign_in customer

      get business_project_thread_path(project, thread)
      expect(response).to have_http_status(:redirect)
      get business_project_threads_path(project)
      expect(response).to have_http_status(:redirect)
      get new_business_project_thread_path(project)
      expect(response).to have_http_status(:redirect)

      expect { create_thread("割り込み") }.not_to change(ProjectThread, :count)
      expect {
        post business_project_thread_project_chats_path(project, thread), params: { project_chat: { body: "割り込み" } }
      }.not_to change(ProjectChat, :count)

      get business_project_path(project)
      expect(response.body).not_to include("内部の相談") if response.successful?
      expect(response.body).not_to include("参加者花子") if response.successful?
    end

    it "同じコミュニティの別プロジェクトの参加者" do
      customer = create(:customer, domain_name: "business")
      CommunityCustomer.create!(community: community, customer: customer)
      ProjectMember.create!(project: other_project, customer: customer)

      expect_no_internal_access(customer)
    end

    it "別コミュニティの参加者" do
      customer = create(:customer, domain_name: "business")
      CommunityCustomer.create!(community: create(:community, owner: owner, domain: business_domain), customer: customer)

      expect_no_internal_access(customer)
      get business_project_path(project)
      expect(response).to redirect_to(business_community_path(community))
    end

    it "プロジェクトの承認待ち" do
      customer = create(:customer, domain_name: "business")
      CommunityCustomer.create!(community: community, customer: customer)
      ProjectJoinRequest.create!(project: project, customer: customer)

      expect_no_internal_access(customer)
    end

    it "プロジェクトのアクセス停止中" do
      Business::Memberships::RevokeProjectAccess.call(project: project, customer: member, suspend: true, actor: owner)

      expect_no_internal_access(member)
    end

    it "コミュニティの参加資格を失ったプロジェクト参加者(旧データでプロジェクトの行だけ残っていても)" do
      CommunityCustomer.where(community: community, customer: other_member).delete_all
      expect(ProjectMember.exists?(project: project, customer: other_member)).to eq true

      expect_no_internal_access(other_member)
    end

    it "未ログイン" do
      get business_project_thread_path(project, thread)

      expect(response).to redirect_to(new_customer_session_path)
    end
  end
end
