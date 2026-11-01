require "rails_helper"

# Business プロジェクトのスレッド投稿 → 参加者への画面内通知・メール → 通知一覧 → スレッドへの移動。
RSpec.describe "Business スレッド投稿の通知", type: :request do
  let(:business_domain) { Domain.find_or_create_by!(name: "business") }
  let(:operator) { create(:customer, name: "運営者", domain_name: "business", confirm_mail: true) }
  let(:community) { create(:community, name: "企画部", owner: operator, domain: business_domain) }
  let(:creator) { create(:customer, name: "主催者", domain_name: "business", confirm_mail: true) }
  let(:project) { Project.create!(community: community, customer: creator, title: "新サービス企画") }
  let(:thread_record) { ProjectThread.create!(project: project, customer: creator, title: "デザイン相談") }
  let(:poster) { create(:customer, name: "投稿した人", domain_name: "business") }
  let(:member) { create(:customer, name: "参加者", domain_name: "business", confirm_mail: true) }
  let(:quiet_member) { create(:customer, domain_name: "business", confirm_mail: false) }
  let(:joined_operator) { create(:customer, domain_name: "business", confirm_mail: true) }

  def join_community(customer)
    CommunityCustomer.find_or_create_by!(community: community, customer: customer)
  end

  def join_project(customer, target = project)
    join_community(customer) if target.community == community
    ProjectMember.find_or_create_by!(project: target, customer: customer)
  end

  def upload(name, content_type = "application/octet-stream")
    fixture_file_upload(Rails.root.join("spec/fixtures/files/business_chat", name), content_type)
  end

  def post_to_thread(params)
    post business_project_thread_project_chats_path(project, thread_record), params: { project_chat: params }
  end

  def notified_ids
    Notification.where(action: "project_message", project_id: project.id).pluck(:visited_id)
  end

  def notification_list
    get business_notifications_path
    Nokogiri::HTML(response.body).at_css(".ba-notifications")
  end

  before do
    join_community(operator)
    join_community(creator)
    join_project(poster)
    join_project(member)
    join_project(quiet_member)
    # 参加している運営者(コミュニティの共同運営者)は参加者として届く
    CommunityOwner.create!(community: community, customer: joined_operator)
    join_project(joined_operator)
  end

  describe "通知先" do
    let!(:admin) { create(:customer, domain_name: "business", is_owner: :admin) }
    let!(:pending) { create(:customer, domain_name: "business", confirm_mail: true) }
    let!(:left) { create(:customer, domain_name: "business", confirm_mail: true) }
    let!(:suspended) { create(:customer, domain_name: "business", confirm_mail: true) }
    let!(:community_suspended) { create(:customer, domain_name: "business", confirm_mail: true) }
    let!(:withdrawn) { create(:customer, domain_name: "business", confirm_mail: true) }
    let!(:other_project_member) { create(:customer, domain_name: "business", confirm_mail: true) }
    let!(:community_only) { create(:customer, domain_name: "business", confirm_mail: true) }

    before do
      join_community(pending)
      ProjectJoinRequest.create!(project: project, customer: pending)

      join_project(left)
      Business::Memberships::RevokeProjectAccess.call(project: project, customer: left)

      join_project(suspended)
      Business::Memberships::RevokeProjectAccess.call(project: project, customer: suspended, suspend: true, actor: operator)
      # 停止の記録があれば、参加の行が(旧データなどで)残っていても届けない
      ProjectMember.create!(project: project, customer: suspended)

      join_project(community_suspended)
      CommunityAccessSuspension.create!(community: community, customer: community_suspended, suspended_by: operator)

      join_project(withdrawn)
      withdrawn.update!(is_deleted: true)

      other_project = Project.create!(community: community, customer: operator, title: "別の企画")
      join_project(other_project_member, other_project)

      join_community(community_only)
      sign_in poster
    end

    it "同じプロジェクトの参加者(主催・参加している運営者を含む)にだけ届き、投稿者本人や管理権限だけの人には届かない" do
      expect { post_to_thread(body: "ラフ案を共有します") }.to change(ProjectChat, :count).by(1)

      expect(notified_ids).to match_array([creator.id, member.id, quiet_member.id, joined_operator.id])
      expect(notified_ids).not_to include(
        poster.id, operator.id, admin.id, pending.id, left.id, suspended.id,
        community_suspended.id, withdrawn.id, other_project_member.id, community_only.id
      )

      chat = ProjectChat.last
      notification = Notification.find_by!(visited: member, project_chat: chat)
      expect(notification).to have_attributes(
        visitor_id: poster.id, action: "project_message", community_id: community.id, project_id: project.id, checked: false
      )
    end

    it "メールは通知した人のうちメール受信を許可している人にだけ送る" do
      expect { post_to_thread(body: "ラフ案を共有します") }
        .to have_enqueued_mail(BusinessProjectChatMailer, :thread_post_mail).exactly(3).times
    end
  end

  describe "投稿の種類" do
    before { sign_in poster }

    it "本文だけ・添付だけ・スタンプだけの投稿で、それぞれ通知する" do
      post_to_thread(body: "本文です")
      post_to_thread(attachments: [upload("sample.pdf", "application/pdf")])
      post_to_thread(stamp_type: "thanks")

      chats = thread_record.project_chats.order(:id).to_a
      expect(chats.size).to eq 3
      expect(chats[1].body).to be_blank
      expect(chats[2].stamp_type).to eq "thanks"
      chats.each do |chat|
        expect(Notification.where(project_chat: chat).pluck(:visited_id))
          .to match_array([creator.id, member.id, quiet_member.id, joined_operator.id])
      end
    end

    it "スレッド指定の無い旧導線(全体トーク)への投稿でも通知する" do
      post business_project_project_chats_path(project), params: { project_chat: { body: "旧画面から" } }

      chat = ProjectChat.last
      expect(chat.project_thread).to be_general
      expect(Notification.where(project_chat: chat).count).to eq 4
    end

    it "メールの登録に失敗しても、投稿した人の画面はエラーにならない" do
      allow(BusinessProjectChatMailer).to receive(:with).and_raise(StandardError, "queue down")

      post_to_thread(body: "共有です")

      expect(response).to redirect_to(business_project_thread_path(project, thread_record))
      expect(Notification.where(project_chat: ProjectChat.last).count).to eq 4
    end

    it "保存できなかった投稿(空・添付の件数超過)では通知しない" do
      expect { post_to_thread(body: "") }.not_to change(Notification, :count)
      expect {
        post_to_thread(attachments: Array.new(6) { upload("sample.pdf", "application/pdf") })
      }.not_to change(Notification, :count)
      expect(ProjectChat.count).to eq 0
    end
  end

  describe Business::ProjectThreads::NotifyPost do
    let(:chat) { ProjectChat.create!(project: project, project_thread: thread_record, customer: poster, body: "共有です") }

    it "巻き戻された(保存が確定していない)投稿では通知しない" do
      rolled_back = nil
      ActiveRecord::Base.transaction do
        rolled_back = ProjectChat.create!(project: project, project_thread: thread_record, customer: poster, body: "取り消し")
        raise ActiveRecord::Rollback
      end

      expect(described_class.call(rolled_back)).to eq []
      expect(Notification.count).to eq 0
    end

    it "検証エラーで保存されていない投稿では通知しない" do
      unsaved = ProjectChat.new(project: project, project_thread: thread_record, customer: poster)
      expect(unsaved.save).to eq false

      expect(described_class.call(unsaved)).to eq []
      expect(Notification.count).to eq 0
    end

    it "同じ投稿で再実行しても、同じ宛先への通知・メールを重ねない" do
      expect { described_class.call(chat) }.to have_enqueued_mail(BusinessProjectChatMailer, :thread_post_mail).exactly(3).times
      expect {
        expect(described_class.call(chat)).to eq []
      }.not_to have_enqueued_mail(BusinessProjectChatMailer, :thread_post_mail)

      expect(Notification.where(project_chat: chat).count).to eq 4
    end

    it "前回の途中までしか届いていなければ、残りの宛先にだけ通知する" do
      Notification.create!(visitor: poster, visited: member, action: "project_message",
                           community_id: community.id, project_id: project.id, project_chat_id: chat.id)

      expect(described_class.call(chat)).to match_array([creator, quiet_member, joined_operator])
      expect(Notification.where(project_chat: chat, visited: member).count).to eq 1
    end

    it "外側のトランザクションが巻き戻されたら、通知もメールの登録も残らない" do
      expect {
        ActiveRecord::Base.transaction do
          described_class.call(chat)
          raise ActiveRecord::Rollback
        end
      }.not_to have_enqueued_mail(BusinessProjectChatMailer, :thread_post_mail)

      expect(Notification.where(project_chat_id: chat.id)).to be_empty
    end

    it "メールは通知の保存がコミットされた後に登録する" do
      enqueued_inside = nil
      ActiveRecord::Base.transaction do
        described_class.call(chat)
        enqueued_inside = ActiveJob::Base.queue_adapter.enqueued_jobs.size
      end

      expect(enqueued_inside).to eq 0
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq 3
    end

    it "既にある通知(同時実行の側が先に作った場合と同じ)は一意制約で弾き、その宛先へはメールも登録しない" do
      Notification.create!(visitor: poster, visited: member, action: "project_message", project_id: project.id, project_chat_id: chat.id)

      expect { described_class.call(chat) }.to have_enqueued_mail(BusinessProjectChatMailer, :thread_post_mail).exactly(2).times
      expect(Notification.where(project_chat: chat).group(:visited_id).count.values).to all(eq 1)
    end

    it "メールの登録に失敗しても投稿・通知は残り、記録を残す(再実行しても通知を作り直さないため、そのメールは送られない)" do
      allow(BusinessProjectChatMailer).to receive(:with).and_raise(StandardError, "queue down")
      allow(Rails.logger).to receive(:error)

      expect(described_class.call(chat).size).to eq 4
      expect(Notification.where(project_chat: chat).count).to eq 4
      expect(Rails.logger).to have_received(:error).with(/enqueue failed notification_id=\d+ StandardError: queue down/).exactly(3).times

      allow(BusinessProjectChatMailer).to receive(:with).and_call_original
      expect { described_class.call(chat) }.not_to have_enqueued_mail(BusinessProjectChatMailer, :thread_post_mail)
    end

    it "同じ投稿・同じ宛先の通知は DB でも1件に制限する" do
      attrs = { visitor: poster, visited: member, action: "project_message", project_id: project.id, project_chat_id: chat.id }
      Notification.create!(attrs)

      expect { Notification.create!(attrs) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "投稿を削除すると、その投稿の通知も消える" do
      described_class.call(chat)

      expect { chat.destroy }.to change(Notification, :count).by(-4)
    end

    it "スレッドを削除すると、その中の投稿の通知も消える" do
      described_class.call(chat)

      expect { thread_record.destroy }.to change(Notification, :count).by(-4)
    end
  end

  describe "通知メールの送信時" do
    include ActiveJob::TestHelper

    let(:chat) { ProjectChat.create!(project: project, project_thread: thread_record, customer: poster, body: "社外秘の本文") }

    def notify_and_capture_mail_jobs
      Business::ProjectThreads::NotifyPost.call(chat)
      enqueued_jobs.select { |job| job["arguments"].first == "BusinessProjectChatMailer" }
    end

    def mail_for(recipient)
      Notification.find_by!(project_chat: chat, visited: recipient)
    end

    def deliver(notification_id)
      BusinessProjectChatMailer.with(notification_id: notification_id).thread_post_mail.deliver_now
    end

    it "メールの引数は通知 ID だけにする(投稿・会員のオブジェクトを渡さない)" do
      jobs = notify_and_capture_mail_jobs

      expect(jobs.size).to eq 3
      params = jobs.map { |job| job["arguments"].last["params"].except("_aj_symbol_keys") }
      expect(params).to all(match("notification_id" => Integer))
    end

    it "該当スレッドの該当投稿へのリンク付きで、本文入りのメールを送る(本文入りは既存仕様)" do
      notify_and_capture_mail_jobs
      delivered = nil

      expect { delivered = deliver(mail_for(member).id) }.to change(ActionMailer::Base.deliveries, :size).by(1)
      body = delivered.body.encoded
      expect(delivered.to).to eq [member.email]
      expect(body).to include("/business/projects/#{project.id}/threads/#{thread_record.id}#post-project_chat-#{chat.id}")
      expect(body).to include("社外秘の本文", "新サービス企画", "デザイン相談", "投稿した人さん")
    end

    {
      "投稿が削除された" => ->(ctx) { ctx.chat.destroy },
      "スレッドが削除された" => ->(ctx) { ctx.thread_record.destroy },
      "プロジェクトが削除された" => ->(ctx) { ctx.project.destroy },
      "宛先の会員データが削除された" => ->(ctx) { ctx.member.destroy }
    }.each do |label, remove|
      it "送信までに#{label}場合は、例外にせず送信を取りやめる" do
        notify_and_capture_mail_jobs
        notification_id = mail_for(member).id
        remove.call(self)

        expect { perform_enqueued_jobs }.not_to raise_error
        expect(ActionMailer::Base.deliveries.map(&:to).flatten).not_to include(member.email)
        expect { deliver(notification_id) }.not_to change(ActionMailer::Base.deliveries, :size)
      end
    end

    {
      "プロジェクトから退出した" => ->(ctx) { Business::Memberships::RevokeProjectAccess.call(project: ctx.project, customer: ctx.member) },
      "アクセスを停止された" => ->(ctx) { Business::Memberships::RevokeProjectAccess.call(project: ctx.project, customer: ctx.member, suspend: true, actor: ctx.operator) },
      "コミュニティから外れた" => ->(ctx) { Business::Memberships::RevokeCommunityAccess.call(community: ctx.community, customer: ctx.member) },
      "退会した" => ->(ctx) { ctx.member.update!(is_deleted: true) },
      "メール受信設定をオフにした" => ->(ctx) { ctx.member.update!(confirm_mail: false) }
    }.each do |label, change_state|
      it "送信までに#{label}人には送らない" do
        notify_and_capture_mail_jobs
        notification_id = mail_for(member).id
        change_state.call(self)

        expect { deliver(notification_id) }.not_to change(ActionMailer::Base.deliveries, :size)
      end
    end

    it "送信までにプロジェクトから退出した運営者には、管理権限が残っていても送らない" do
      notify_and_capture_mail_jobs
      notification_id = mail_for(joined_operator).id
      Business::Memberships::RevokeProjectAccess.call(project: project, customer: joined_operator)

      expect(joined_operator.business_project_participant?(project)).to eq true
      expect { deliver(notification_id) }.not_to change(ActionMailer::Base.deliveries, :size)
    end

    it "存在しない通知 ID・別の種類の通知 ID では送らない" do
      follow = Notification.create!(visitor: poster, visited: member, action: "follow")

      expect { deliver(0) }.not_to change(ActionMailer::Base.deliveries, :size)
      expect { deliver(follow.id) }.not_to change(ActionMailer::Base.deliveries, :size)
    end

    describe "更新前に登録された形式のジョブ(CustomerMailer#business_project_chat_mail)" do
      def enqueue_legacy(recipient)
        CustomerMailer.with(ac_customer: poster, ps_customer: recipient, project: project, project_chat: chat)
                      .business_project_chat_mail.deliver_later
      end

      it "新しいコードでもエラーにならず、該当投稿へのリンク付きで送る" do
        enqueue_legacy(member)

        expect { perform_enqueued_jobs }.to change(ActionMailer::Base.deliveries, :size).by(1)
        expect(ActionMailer::Base.deliveries.last.body.encoded)
          .to include("/business/projects/#{project.id}/threads/#{thread_record.id}#post-project_chat-#{chat.id}")
      end

      it "送信時に受信設定オフ・退出を確かめ直す" do
        member.update!(confirm_mail: false)
        enqueue_legacy(member)
        enqueue_legacy(quiet_member)
        Business::Memberships::RevokeProjectAccess.call(project: project, customer: joined_operator)
        enqueue_legacy(joined_operator)

        expect { perform_enqueued_jobs }.not_to change(ActionMailer::Base.deliveries, :size)
      end
    end
  end

  describe "通知一覧と移動先" do
    let!(:chat) do
      ProjectChat.create!(project: project, project_thread: thread_record, customer: poster, body: "社外秘の本文",
                          attachments: [upload("sample.pdf", "application/pdf")]).tap do |record|
        Business::ProjectThreads::NotifyPost.call(record)
      end
    end
    let(:thread_anchor_path) { business_project_thread_path(project, thread_record, anchor: "post-project_chat-#{chat.id}") }

    before { sign_in member }

    it "コミュニティ名・プロジェクト名・スレッド名と投稿者を出し、本文・添付の URL は出さない" do
      list = notification_list
      item = list.at_css(".ba-notification")

      expect(item.text).to include("投稿した人がスレッドに投稿しました")
      expect(item.at_css(".ba-notification__context").text.strip).to eq "企画部 / 新サービス企画 / デザイン相談"
      expect(item["href"]).to eq thread_anchor_path
      expect(list.text).not_to include("社外秘の本文", "sample.pdf")
      expect(list.to_html).not_to include("rails/active_storage", "/attachments/")
    end

    it "通知から該当スレッドの該当投稿へ移動できる" do
      get thread_anchor_path

      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).at_css("#post-project_chat-#{chat.id}").text).to include("社外秘の本文")
    end

    it "未読件数に数え、一覧を開くと既読になる" do
      get business_root_path
      expect(Nokogiri::HTML(response.body).at_css(".ba-sidenav .ba-nav-badge").text.strip).to eq "1"

      list = notification_list
      expect(list.css(".ba-notification.is-unread").size).to eq 1
      expect(Notification.find_by!(visited: member, project_chat: chat).checked).to eq true

      get business_root_path
      expect(Nokogiri::HTML(response.body).at_css(".ba-sidenav .ba-nav-badge")).to be_nil

      expect(notification_list.css(".ba-notification.is-unread")).to be_empty
    end

    shared_examples "権限を失ったあとの通知" do
      it "一覧に名前・プロジェクト名・スレッド名やリンクを出さず、スレッドへも直接アクセスできない" do
        list = notification_list
        item = list.at_css(".ba-notification")

        expect(item.name).not_to eq "a"
        expect(item.text).to include("閲覧できなくなったプロジェクトの通知です")
        expect(list.text).not_to include("投稿した人", "企画部", "新サービス企画", "デザイン相談", "社外秘の本文")
        expect(list.at_css("a")).to be_nil

        get thread_anchor_path
        expect(response).to have_http_status(:redirect)
        follow_redirect!
        expect(response.body).not_to include("社外秘の本文")
      end
    end

    context "プロジェクトから退出した場合" do
      before { Business::Memberships::RevokeProjectAccess.call(project: project, customer: member) }

      include_examples "権限を失ったあとの通知"
    end

    context "プロジェクトのアクセスを停止された場合" do
      before { Business::Memberships::RevokeProjectAccess.call(project: project, customer: member, suspend: true, actor: operator) }

      include_examples "権限を失ったあとの通知"
    end

    context "コミュニティから外れた場合" do
      before { Business::Memberships::RevokeCommunityAccess.call(community: community, customer: member) }

      include_examples "権限を失ったあとの通知"
    end

    it "移行前のスレッド情報が無い通知も、閲覧できなくなったら名前・リンクを出さない" do
      Notification.create!(visitor: poster, visited: member, action: "project_message",
                           community_id: community.id, project_id: project.id)
      Business::Memberships::RevokeProjectAccess.call(project: project, customer: member)

      list = notification_list
      expect(list.css(".ba-notification").map(&:text)).to all(include("閲覧できなくなったプロジェクトの通知です"))
      expect(list.text).not_to include("投稿した人", "新サービス企画")
      expect(list.at_css("a")).to be_nil
    end

    it "参加通知など今回対象外の種類は、従来どおりの表示とリンクのまま" do
      Notification.create!(visitor: poster, visited: member, action: "project_joined",
                           community_id: community.id, project_id: project.id)
      Business::Memberships::RevokeProjectAccess.call(project: project, customer: member)

      joined = notification_list.css("a.ba-notification").find { |link| link.text.include?("プロジェクトに参加しました") }
      expect(joined.text).to include("投稿した人がプロジェクトに参加しました")
      expect(joined["href"]).to eq business_project_path(project)
    end

    it "移行前のスレッド情報が無い通知は、閲覧できる間はプロジェクトへ移動する" do
      legacy = Notification.create!(visitor: poster, visited: member, action: "project_message",
                                    community_id: community.id, project_id: project.id)

      links = notification_list.css("a.ba-notification").map { |link| link["href"] }
      expect(links).to include(business_project_path(project))
      expect(legacy.reload.checked).to eq true
    end
  end
end
