require "rails_helper"

# デプロイ中の旧コードが残した投稿、作成者の退会・削除、アクセス停止後のメール送信。
RSpec.describe "Business プロジェクトスレッドの移行・退会・停止後", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:owner) { create(:customer, domain_name: "business") }
  let(:community) { create(:community, owner: owner, domain: business_domain) }
  let(:project) { Project.create!(community: community, customer: owner, title: "A社ホームページ制作") }
  let(:member) { create(:customer, domain_name: "business", name: "参加者太郎") }
  let(:creator) { create(:customer, domain_name: "business", name: "スレッド作成者") }

  before do
    [owner, member, creator].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    [member, creator].each { |customer| ProjectMember.create!(project: project, customer: customer) }
  end

  describe "旧コードが書き込んだスレッド未所属の投稿" do
    # マイグレーション後〜Puma 再起動前に旧コードが書き込んだ行を再現する。
    let!(:legacy_chat) do
      ProjectChat.create!(project: project, customer: member, body: "デプロイ中の投稿").tap do |chat|
        chat.update_columns(project_thread_id: nil, created_at: 1.minute.from_now)
      end
    end

    before { sign_in owner }

    it "手動の backfill を待たずに、プロジェクト・スレッド画面を開くと「全体トーク」に表示される" do
      default_thread = ProjectThread.default_for(project)

      get business_project_path(project)
      expect(legacy_chat.reload.project_thread).to eq default_thread

      get business_project_thread_path(project, default_thread)
      expect(response.body).to include("デプロイ中の投稿")
      expect(default_thread.reload.last_posted_at).to be_within(1.second).of(legacy_chat.created_at)
    end

    it "紐づけに失敗しても画面は表示し、投稿が消えていないことと再読み込みの導線を出し、ログに残す" do
      allow(Business::ProjectThreads::LegacyChatBackfill).to receive(:call).and_raise(ActiveRecord::LockWaitTimeout)
      allow(Rails.logger).to receive(:error)

      [business_project_path(project), business_project_threads_path(project),
       business_project_thread_path(project, ProjectThread.default_for(project))].each do |path|
        get path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("一部の過去の投稿を表示できていない可能性があります（投稿は削除されていません）")
        expect(response.body).to include(%(href="#{path}">再読み込みする))
      end
      expect(Rails.logger).to have_received(:error).with(/LegacyChatBackfill\] failed project_id=#{project.id}/).at_least(:once)
      expect(legacy_chat.reload.body).to eq "デプロイ中の投稿"

      # 再試行(再読み込み)で成功すれば案内は消え、投稿が表示される。
      allow(Business::ProjectThreads::LegacyChatBackfill).to receive(:call).and_call_original
      get business_project_thread_path(project, ProjectThread.default_for(project))
      expect(response.body).not_to include("表示できていない可能性があります")
      expect(response.body).to include("デプロイ中の投稿")
    end

    it "旧コードで作られた(全体トークの無い)プロジェクトも、開けば全体トークが用意され、旧導線の投稿もそこへ入る" do
      legacy = Project.create!(community: community, customer: owner, title: "旧コードで作成")
      legacy.project_threads.delete_all

      get business_project_path(legacy)
      general = ProjectThread.default_for(legacy)
      expect(general&.title).to eq "全体トーク"
      expect(response.body).to include("全体トーク")

      post business_project_project_chats_path(legacy), params: { project_chat: { body: "旧画面からの投稿" } }
      expect(general.project_chats.pluck(:body)).to eq ["旧画面からの投稿"]
      expect(legacy.project_threads.count).to eq 1
    end

    it "ほかのプロジェクトの未所属投稿には触れない" do
      other = Project.create!(community: community, customer: owner, title: "別案件")
      other_chat = ProjectChat.create!(project: other, customer: owner, body: "別案件の投稿")
      other_chat.update_column(:project_thread_id, nil)

      get business_project_threads_path(project)

      expect(legacy_chat.reload.project_thread_id).to be_present
      expect(other_chat.reload.project_thread_id).to be_nil
    end
  end

  describe "スレッド作成者の退会・削除" do
    let!(:thread) { project.project_threads.create!(customer: creator, title: "デザイン相談") }
    let!(:member_chat) do
      chat = ProjectChat.create!(project: project, project_thread: thread, customer: member, body: "ほかの参加者の会話")
      chat.attachments.attach(io: StringIO.new("%PDF-1.4"), filename: "spec.pdf", content_type: "application/pdf")
      chat
    end

    it "退会(is_deleted)するとスレッドと会話は残り、作成者は「退会済みユーザー」と表示される" do
      creator.update!(is_deleted: true)
      sign_in member

      get business_project_threads_path(project)
      expect(response.body).to include("作成：退会済みユーザー")
      expect(response.body).not_to include("スレッド作成者")

      get business_project_thread_path(project, thread)
      expect(response.body).to include("ほかの参加者の会話")
      post business_project_thread_project_chats_path(project, thread), params: { project_chat: { body: "続きの相談" } }
      expect(thread.project_chats.pluck(:body)).to include("続きの相談")
    end

    it "会員データを完全削除しても失敗せず、スレッド・ほかの参加者の投稿・添付は残る" do
      expect { creator.destroy! }.not_to raise_error

      thread.reload
      expect(thread.customer_id).to be_nil
      expect(member_chat.reload.attachments.count).to eq 1

      sign_in member
      get business_project_thread_path(project, thread)
      expect(response.body).to include("作成：退会済みユーザー")
      expect(response.body).to include("ほかの参加者の会話")

      # 作成者がいなくなったスレッドの編集・削除は管理者だけ。
      patch business_project_thread_path(project, thread), params: { project_thread: { title: "変更" } }
      expect(thread.reload.title).to eq "デザイン相談"
      sign_in owner
      patch business_project_thread_path(project, thread), params: { project_thread: { title: "管理者が変更" } }
      expect(thread.reload.title).to eq "管理者が変更"
    end
  end

  describe "全体トーク" do
    it "管理者でも削除できず、削除ボタンも出ない(タイトル・説明は編集できる)" do
      general = ProjectThread.default_for(project)
      sign_in owner

      get business_project_thread_path(project, general)
      expect(response.body).not_to include('data-method="delete" href="' + business_project_thread_path(project, general) + '"')

      expect { delete business_project_thread_path(project, general) }.not_to change(ProjectThread, :count)
      expect(flash[:alert]).to eq "「全体トーク」は削除できません。"

      patch business_project_thread_path(project, general), params: { project_thread: { title: "連絡用" } }
      expect(general.reload.title).to eq "連絡用"
    end
  end

  describe "プロジェクト作成者の完全削除" do
    let(:creator_project) { Project.create!(community: community, customer: creator, title: "作成者の企画") }
    let!(:topic) { creator_project.project_threads.create!(customer: member, title: "進め方") }

    before do
      ProjectMember.create!(project: creator_project, customer: member)
      chat = ProjectChat.create!(project: creator_project, project_thread: topic, customer: member, body: "参加者の会話")
      chat.attachments.attach(io: StringIO.new("%PDF-1.4"), filename: "spec.pdf", content_type: "application/pdf")
    end

    it "プロジェクト・スレッド・ほかの参加者の投稿と添付を残し、運営者が引き続き管理できる" do
      expect { creator.destroy! }.not_to change(ProjectChat, :count)

      creator_project.reload
      expect(creator_project.customer_id).to be_nil
      expect(creator_project.project_threads.pluck(:title)).to contain_exactly("全体トーク", "進め方")
      expect(ProjectThread.default_for(creator_project).customer_id).to be_nil
      expect(topic.project_chats.first.attachments.count).to eq 1

      sign_in member
      get business_project_path(creator_project)
      expect(response.body).to include("👤 退会済みユーザー")
      get business_project_thread_path(creator_project, topic)
      expect(response.body).to include("参加者の会話")

      sign_in owner
      patch business_project_path(creator_project), params: { project: { title: "運営者が引き継ぎ" } }
      expect(creator_project.reload.title).to eq "運営者が引き継ぎ"
      expect(creator_project.accessible_customers).to include(owner, member)
    end
  end

  describe "通知メール(deliver_later)の送信時" do
    let(:chat) { ProjectChat.create!(project: project, customer: owner, body: "社外秘の内容") }

    def deliver_to(recipient)
      CustomerMailer.with(ac_customer: owner, ps_customer: recipient, project: project, project_chat: chat)
                    .business_project_chat_mail.deliver_now
    end

    it "送信までにアクセス停止・退出・退会した人には本文を送らない" do
      Business::Memberships::RevokeProjectAccess.call(project: project, customer: member, suspend: true, actor: owner)
      creator.update!(is_deleted: true)

      expect { deliver_to(member) }.not_to change(ActionMailer::Base.deliveries, :size)
      expect { deliver_to(creator) }.not_to change(ActionMailer::Base.deliveries, :size)
    end

    it "閲覧できる人にはスレッドの URL 付きで送る" do
      delivered = nil
      expect { delivered = deliver_to(member) }.to change(ActionMailer::Base.deliveries, :size).by(1)
      expect(delivered.body.encoded).to include("/business/projects/#{project.id}/threads/#{chat.project_thread_id}")
    end
  end
end
