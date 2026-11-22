require "rails_helper"

# 退会した会員へ、新しい通知が作られない・届かないこと(メール・LINE・画面内の通知)。
# 実際のメール送信はせず、ActionMailer の :test 配信と ActiveJob の :test アダプタで確かめる。
RSpec.describe "退会者への通知停止" do
  include ActiveJob::TestHelper

  let(:actor) { create(:customer, name: "操作した人") }
  let(:recipient) { create(:customer, name: "退会する人", confirm_mail: true) }
  let(:active_recipient) { create(:customer, name: "現役の人", confirm_mail: true) }
  let(:deliveries) { ActionMailer::Base.deliveries }

  before { deliveries.clear }

  def withdraw(customer)
    result = Customers::Withdrawal::Execute.call(Customer.find(customer.id))
    raise "退会できませんでした: #{result.plan.blockers.map(&:key)}" unless result.withdrawn?
  end

  def delivered_addresses
    deliveries.flat_map { |mail| Array(mail.to) + Array(mail.bcc) }
  end

  describe "メール" do
    it "退会前に予約(deliver_later)したメールは、退会後の配信時に送らない" do
      CustomerMailer.with(ac_customer: actor, ps_customer: recipient).create_follow_mail.deliver_later
      withdraw(recipient)

      perform_enqueued_jobs

      expect(deliveries).to be_empty
    end

    it "同じ配信ジョブを再実行(リトライ)しても送らず、例外にもならない" do
      CustomerMailer.with(ac_customer: actor, ps_customer: recipient).create_follow_mail.deliver_later
      job = enqueued_jobs.first
      withdraw(recipient)

      expect { 2.times { ActiveJob::Base.execute(job) } }.not_to raise_error
      expect(deliveries).to be_empty
    end

    it "メールアドレスの置き換えに頼らず、宛先の利用停止(DB の状態)を配信直前に確かめて止める" do
      CustomerMailer.with(ac_customer: actor, ps_customer: recipient).create_follow_mail.deliver_later
      # アドレスは実在のまま、管理画面の「退会」と同じ状態にする。
      recipient.update_columns(is_deleted: true)

      perform_enqueued_jobs

      expect(deliveries).to be_empty
    end

    it "現役の宛先には送る。操作した人が退会していても止めない" do
      CustomerMailer.with(ac_customer: actor, ps_customer: active_recipient).create_follow_mail.deliver_later
      withdraw(actor)

      perform_enqueued_jobs

      expect(delivered_addresses).to eq([active_recipient.email])
    end

    it "複数宛先のお知らせメールは、退会者だけを外してほかのメンバーへ送る" do
      withdraw(recipient)
      community = create(:community, owner_id: actor.id)

      ContactMailer.send_mail("お知らせ", "本文", community, Customer.where(id: [recipient.id, active_recipient.id])).deliver_now

      expect(delivered_addresses).to eq([active_recipient.email])
    end

    it "複数宛先がすべて退会者なら送らない" do
      withdraw(recipient)
      community = create(:community, owner_id: actor.id)

      ContactMailer.send_mail("お知らせ", "本文", community, Customer.where(id: recipient.id)).deliver_now

      expect(deliveries).to be_empty
    end

    it "エントリー依頼メールは、退会した宛先へ送らない" do
      community = create(:community, owner_id: actor.id)
      event = build(:event, customer: actor, community: community, event_start_time: 30.days.from_now,
                            event_end_time: 30.days.from_now + 1.hour, event_entry_deadline: 20.days.from_now)
      event.songs << build(:song, event: event)
      event.save!
      invitation = create(:entry_invitation, customer: recipient, requested_by_customer: actor, event_for_invitation: event)
      withdraw(recipient)

      EntryInvitationMailer.invite(invitation.reload).deliver_now

      expect(deliveries).to be_empty
    end

    it "エントリー依頼のジョブは、退会した宛先を「送信済み」にせず対象外にする" do
      community = create(:community, owner_id: actor.id)
      event = build(:event, customer: actor, community: community, event_start_time: 30.days.from_now,
                            event_end_time: 30.days.from_now + 1.hour, event_entry_deadline: 20.days.from_now)
      event.songs << build(:song, event: event)
      event.save!
      invitation = create(:entry_invitation, customer: recipient, requested_by_customer: actor, event_for_invitation: event)
      # 退会処理を経ずに利用停止された場合(管理画面の「退会」)も、送信直前の確認で止まる。
      recipient.update_columns(is_deleted: true)

      SendEntryInvitationJob.perform_now(invitation.id)

      expect(deliveries).to be_empty
      expect(invitation.reload).to be_skipped
    end

    it "締め切りリマインドメールは、退会した宛先へ送らない" do
      community = create(:community, owner_id: actor.id)
      event = create(:event, :event_with_songs, customer: actor, community: community,
                                                event_start_time: 10.days.from_now, event_end_time: 10.days.from_now + 2.hours,
                                                event_entry_deadline: 5.days.from_now)
      reminder = EventDeadlineReminder.create!(event: event, kind: "entry", channel: "mail")
      delivery = reminder.deliveries.create!(customer: recipient, status: :sending)
      message = EventDeadlineReminders::MessageBuilder.call(event: event, kind: "entry", sent_at: Time.current)
      withdraw(recipient)

      EventDeadlineReminderMailer.with(delivery: delivery, message: message).remind.deliver_now

      expect(deliveries).to be_empty
    end

    it "締め切りリマインドの送信対象から、退会者を外す" do
      community = create(:community, owner_id: actor.id)
      event = create(:event, :event_with_songs, customer: actor, community: community,
                                                event_start_time: 10.days.from_now, event_end_time: 10.days.from_now + 2.hours,
                                                event_entry_deadline: 5.days.from_now)
      CommunityCustomer.create!(community: community, customer: recipient)
      CommunityCustomer.create!(community: community, customer: active_recipient)
      withdraw(recipient)

      resolver = EventDeadlineReminders::RecipientResolver.new(event)

      expect(resolver.call).to eq([active_recipient])
      expect(resolver.eligible?(recipient)).to be(false)
    end

    it "学習サービス: 先生が利用停止されていれば、生徒へのメールを送らない" do
      student = create(:learning_student, customer: recipient, email: "student@example.com")
      recipient.update_columns(is_deleted: true)

      LearningMailer.with(teacher: recipient, student: student).student_portal_mail.deliver_now

      expect(deliveries).to be_empty
    end

    it "Devise: 退会したアカウントへはパスワード再設定・確認のメールを送らない" do
      withdraw(recipient)
      withdrawn = Customer.find(recipient.id)

      withdrawn.send_reset_password_instructions
      withdrawn.send_confirmation_instructions

      expect(deliveries).to be_empty
    end

    it "退会したアカウントの置き換え後の宛先(@withdrawn.invalid)は、どのメーラーからでも外す" do
      stub_const("WithdrawnTestMailer", Class.new(ApplicationMailer) do
        def notice(addresses)
          mail(to: addresses, subject: "テスト", body: "本文")
        end
      end)

      WithdrawnTestMailer.notice(["withdrawn-1-abc@withdrawn.invalid"]).deliver_now
      expect(deliveries).to be_empty

      WithdrawnTestMailer.notice(["withdrawn-1-abc@withdrawn.invalid", "keep@example.com"]).deliver_now
      expect(delivered_addresses).to eq(["keep@example.com"])
    end
  end

  describe "画面内の通知" do
    it "退会者宛ての通知は作らない(画面を開いた後に退会した場合も、DB を読み直して止める)" do
      stale_recipient = Customer.find(recipient.id)
      withdraw(recipient)

      expect {
        stale_recipient.create_notification_follow(actor)
        stale_recipient.create_notification_chat(actor)
        stale_recipient.create_notification_event_for_community(actor, 1)
      }.not_to change(Notification.unscoped, :count)
    end

    it "現役の会員への通知は作る" do
      expect { active_recipient.create_notification_chat(actor) }.to change(Notification.unscoped, :count).by(1)
    end

    it "参加申請の通知は、承認者が退会していれば作らず、例外にもしない" do
      stale_recipient = Customer.find(recipient.id)
      withdraw(recipient)

      expect {
        expect(JoinRequestNotifications.notify!(applicant: actor, recipient: stale_recipient,
                                                action: JoinRequestNotifications::COMMUNITY_ACTION, community_id: 1)).to be_nil
      }.not_to change(Notification.unscoped, :count)
    end

    it "Business スレッド投稿: 宛先を選んだ後に退会した人だけを飛ばし、ほかの参加者には通知・メールする" do
      business = Domain.find_or_create_by!(name: "business")
      community = create(:community, owner_id: actor.id, domain: business)
      project = Project.create!(community: community, customer: actor, title: "企画")
      thread = ProjectThread.create!(project: project, customer: actor, title: "相談")
      chat = ProjectChat.create!(project: project, project_thread: thread, customer: actor, body: "共有します")
      [recipient, active_recipient].each do |member|
        CommunityCustomer.create!(community: community, customer: member)
        ProjectMember.create!(project: project, customer: member)
      end
      stale_recipient = Customer.find(recipient.id)
      allow_any_instance_of(Project).to receive(:thread_post_notification_recipients).and_return([stale_recipient, active_recipient])
      withdraw(recipient)

      notified = perform_enqueued_jobs { Business::ProjectThreads::NotifyPost.call(chat) }

      expect(notified).to eq([active_recipient])
      expect(Notification.where(action: "project_message").pluck(:visited_id)).to eq([active_recipient.id])
      expect(delivered_addresses).to eq([active_recipient.email])
    end
  end

  describe "LINE(学習サービス)" do
    around do |example|
      original = ENV["LINE_CHANNEL_ACCESS_TOKEN"]
      ENV["LINE_CHANNEL_ACCESS_TOKEN"] = "test-token"
      example.run
    ensure
      ENV["LINE_CHANNEL_ACCESS_TOKEN"] = original
    end

    it "先生が利用停止されていれば、LINE へ送らずに skipped にする" do
      student = create(:learning_student, customer: recipient)
      create(:learning_line_connection, customer: recipient, learning_student: student,
                                        line_user_id: "UrealLineUserId", status: "connected", connected_at: Time.current)
      log = create(:learning_notification_log, customer: recipient, learning_student: student,
                                               delivery_channel: "line", status: "queued")
      recipient.update_columns(is_deleted: true)
      http_client = double("http_client")
      expect(http_client).not_to receive(:start)

      result = Learning::LineNotificationAdapter.new(http_client: http_client).deliver(log)

      expect(result.status).to eq(:withdrawn)
      expect(log.reload.status).to eq("skipped")
    end
  end
end
