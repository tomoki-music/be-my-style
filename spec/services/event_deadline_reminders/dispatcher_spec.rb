require "rails_helper"

RSpec.describe EventDeadlineReminders::Dispatcher do
  include ActiveSupport::Testing::TimeHelpers

  let(:jst) { Time.find_zone("Asia/Tokyo") }
  let(:owner) { FactoryBot.create(:customer, name: "主催者") }
  let(:community) { FactoryBot.create(:community, owner_id: owner.id) }
  let!(:member_a) { FactoryBot.create(:customer) }
  let!(:member_b) { FactoryBot.create(:customer) }
  let(:entry_deadline) { jst.parse("2026-10-17 23:59") }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs,
      customer: owner, community: community,
      event_start_time: jst.parse("2026-10-25 18:00"),
      event_end_time: jst.parse("2026-10-25 21:00"),
      event_entry_deadline: entry_deadline,
      request_deadline: jst.parse("2026-10-17 23:00")
    )
  end
  let(:chat_room) { ChatRoom.create! }

  before do
    [owner, member_a, member_b].each { |customer| CommunityCustomer.create!(community: community, customer: customer) }
    ChatRoomCustomer.create!(chat_room: chat_room, customer: owner, community: community)
    ActionMailer::Base.deliveries.clear
  end

  after { travel_back }

  # 設定は送信予定日時(11:59 JST)より前に行う。
  def enable!(kind: "entry", channel: "mail")
    travel_to(jst.parse("2026-10-17 08:00"))
    event.update!(deadline_reminders_attributes: [{ kind: kind, enabled: "1", channel: channel }])
    event.deadline_reminders.reload.detect { |reminder| reminder.kind == kind }
  end

  def dispatch_at(time)
    travel_to(time)
    described_class.call(now: Time.current)
  end

  describe "送信タイミング" do
    it "送信予定日時(締め切り12時間前)より前は送らないこと" do
      reminder = enable!
      dispatch_at(jst.parse("2026-10-17 11:58"))

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(reminder.reload).to be_pending
    end

    it "送信予定日時を過ぎた最初の実行で送ること" do
      reminder = enable!
      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(reminder.reload).to be_sent
      expect(ActionMailer::Base.deliveries.size).to eq 3
    end

    it "定期処理停止で予定を過ぎても、締め切り前なら次回実行で送ること" do
      reminder = enable!
      dispatch_at(jst.parse("2026-10-17 18:00"))

      expect(reminder.reload).to be_sent
    end

    it "締め切りを過ぎたら送らないこと" do
      reminder = enable!
      dispatch_at(jst.parse("2026-10-17 23:59"))

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(reminder.reload).to be_pending
    end
  end

  describe "メール配信" do
    it "受信者ごとに1通ずつ、宛先を他の受信者に公開せず送ること" do
      reminder = enable!
      dispatch_at(jst.parse("2026-10-17 12:00"))

      mails = ActionMailer::Base.deliveries
      expect(mails.map(&:to)).to contain_exactly([owner.email], [member_a.email], [member_b.email])
      expect(mails.map { |mail| [mail.cc, mail.bcc] }.flatten.compact).to be_empty
      expect(mails.first.subject).to eq "【BeMyStyle】【本日締め切り🎸】#{event.event_name}のエントリー受付について"
      expect(reminder.reload.delivered_count).to eq 3
      expect(reminder.deliveries.delivered.count).to eq 3
      expect(reminder).to be_sent_via_mail
      expect(reminder.sent_for_deadline).to eq entry_deadline
    end

    it "再実行しても成功済みの受信者へ再送しないこと" do
      enable!
      dispatch_at(jst.parse("2026-10-17 12:00"))
      dispatch_at(jst.parse("2026-10-17 12:05"))

      expect(ActionMailer::Base.deliveries.size).to eq 3
      expect(EventDeadlineReminderDelivery.count).to eq 3
    end

    it "別プロセスが処理中(sending)のリマインドは確保できず送らないこと" do
      reminder = enable!
      travel_to(jst.parse("2026-10-17 12:00"))
      reminder.update_columns(status: EventDeadlineReminder.statuses[:sending], started_at: Time.current)

      described_class.call(now: Time.current + 5.minutes)

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "中断されたまま一定時間たったリマインドは引き継ぎ、結果不明の受信者には再送しないこと" do
      reminder = enable!
      travel_to(jst.parse("2026-10-17 12:00"))
      reminder.update_columns(status: EventDeadlineReminder.statuses[:sending], started_at: Time.current)
      reminder.deliveries.create!(customer: owner, status: :delivered, delivered_at: Time.current)
      in_flight = reminder.deliveries.create!(customer: member_a, status: :sending)

      dispatch_at(jst.parse("2026-10-17 12:20"))

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq [[member_b.email]]
      expect(in_flight.reload).to be_failed
      expect(in_flight.failure_reason).to include("結果が不明")
      expect(reminder.reload).to be_sent
      expect([reminder.delivered_count, reminder.failed_count]).to eq [2, 1]
    end

    it "一部の受信者への送信が失敗しても他の受信者には送り、結果を受信者単位で残すこと" do
      reminder = enable!
      original = EventDeadlineReminderMailer.method(:with)
      allow(EventDeadlineReminderMailer).to receive(:with) do |params|
        raise Net::SMTPFatalError, "550 rejected" if params[:delivery].customer_id == member_a.id

        original.call(params)
      end

      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(ActionMailer::Base.deliveries.size).to eq 2
      failed = reminder.deliveries.find_by(customer: member_a)
      expect(failed).to be_failed
      expect(failed.failure_reason).to include("550 rejected")
      expect(reminder.reload).to be_sent
      expect(reminder.failed_count).to eq 1
    end

    it "全員への送信が失敗したら失敗として扱い、自動再送しないこと" do
      reminder = enable!
      allow(EventDeadlineReminderMailer).to receive(:with).and_raise(Net::SMTPAuthenticationError, "535 auth")

      dispatch_at(jst.parse("2026-10-17 12:00"))
      dispatch_at(jst.parse("2026-10-17 12:30"))

      expect(reminder.reload).to be_failed
      expect(EventDeadlineReminderDelivery.count).to eq 3
    end

    it "メール受信設定がオフのメンバーには送らないこと" do
      member_b.update!(confirm_mail: false)
      enable!
      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(ActionMailer::Base.deliveries.map(&:to).flatten).not_to include(member_b.email)
    end
  end

  describe "コミュニティチャット配信" do
    it "開催コミュニティのチャットへ自動お知らせとして1件だけ投稿し、メールは送らないこと" do
      reminder = enable!(channel: "chat")

      expect do
        dispatch_at(jst.parse("2026-10-17 12:00"))
        dispatch_at(jst.parse("2026-10-17 12:05"))
      end.to change(ChatMessage, :count).by(1)

      message = ChatMessage.last
      expect(message.chat_room).to eq chat_room
      expect(message.community).to eq community
      expect(message.customer).to eq owner
      expect(message).to be_system_generated
      expect(message).to be_markdown
      expect(message.content).to include("エントリー受付について")
      expect(message.content_editable?).to eq false
      expect(reminder.reload).to be_sent
      expect(reminder.chat_message).to eq message
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "投稿者以外のメンバーへアプリ内通知を作ること" do
      enable!(channel: "chat")

      expect { dispatch_at(jst.parse("2026-10-17 12:00")) }
        .to change { Notification.where(action: "group_chat", community_id: community.id).count }.by(2)
    end

    it "主催者が退会済みならコミュニティオーナー名義で投稿すること" do
      organizer = FactoryBot.create(:customer)
      CommunityCustomer.create!(community: community, customer: organizer)
      event.update!(customer: organizer)
      enable!(channel: "chat")
      organizer.update_columns(is_deleted: true)

      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(ChatMessage.last.customer).to eq owner
    end

    it "コミュニティチャットのルームが無ければ失敗として記録すること" do
      ChatRoomCustomer.delete_all
      reminder = enable!(channel: "chat")

      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(reminder.reload).to be_failed
      expect(reminder.failure_reason).to include("ルームが見つかりません")
    end
  end

  describe "設定・イベントの変更" do
    it "無効化された通知は送らないこと" do
      reminder = enable!
      event.update!(deadline_reminders_attributes: [{ id: reminder.id, enabled: "0" }])
      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "送信前に締め切りが延長されたら新しい予定日時に追従すること" do
      reminder = enable!
      event.update!(event_entry_deadline: jst.parse("2026-10-18 23:59"))

      dispatch_at(jst.parse("2026-10-17 12:00"))
      expect(ActionMailer::Base.deliveries).to be_empty

      dispatch_at(jst.parse("2026-10-18 11:59"))
      expect(reminder.reload).to be_sent
      expect(reminder.sent_for_deadline).to eq jst.parse("2026-10-18 23:59")
    end

    it "締め切り変更で予定日時が過去になったら即送信しないこと" do
      reminder = enable!
      travel_to(jst.parse("2026-10-17 10:00"))
      event.update!(event_entry_deadline: jst.parse("2026-10-17 20:00"))

      dispatch_at(jst.parse("2026-10-17 10:05"))

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(reminder.reload).to be_disarmed_by_deadline_changed_past
    end

    it "送信予定日時を過ぎてから有効化した場合は即送信しないこと" do
      travel_to(jst.parse("2026-10-17 13:00"))
      event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "mail" }])

      dispatch_at(jst.parse("2026-10-17 13:05"))

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "DBの締め切りがコールバックを経ずに変わった場合も、記録と一致しなければ送らないこと" do
      enable!
      event.update_columns(event_entry_deadline: jst.parse("2026-10-17 22:00"))

      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "開催開始後のイベントには送らないこと" do
      enable!
      event.update_columns(event_start_time: jst.parse("2026-10-17 11:00"))

      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "送信済みの後に配信方法をチャットへ切り替えても再送しないこと" do
      reminder = enable!
      dispatch_at(jst.parse("2026-10-17 12:00"))
      event.update!(deadline_reminders_attributes: [{ id: reminder.id, channel: "chat" }])

      expect { dispatch_at(jst.parse("2026-10-17 12:10")) }.not_to change(ChatMessage, :count)
      expect(ActionMailer::Base.deliveries.size).to eq 3
    end

    it "リクエストとエントリーの締め切りは別々の通知として送ること" do
      enable!(kind: "request", channel: "chat")
      enable!(kind: "entry", channel: "chat")

      expect { dispatch_at(jst.parse("2026-10-17 12:00")) }.to change(ChatMessage, :count).by(2)
      expect(ChatMessage.pluck(:content).join).to include("曲リクエスト受付", "エントリー受付")
    end
  end

  describe "失敗・中断時の扱い" do
    def stall!(reminder, at:)
      reminder.update_columns(status: EventDeadlineReminder.statuses[:sending], started_at: at)
    end

    it "送信中のまま停止し締め切りを過ぎたものは、結果不明の宛先を記録して送信済みで確定し、再送しないこと" do
      reminder = enable!
      stall!(reminder, at: jst.parse("2026-10-17 12:00"))
      reminder.deliveries.create!(customer: owner, status: :delivered, delivered_at: Time.current)
      in_flight = reminder.deliveries.create!(customer: member_a, status: :sending)

      dispatch_at(jst.parse("2026-10-18 06:05"))

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(in_flight.reload).to be_failed
      expect(in_flight.failure_reason).to start_with("[結果不明]")
      expect(reminder.reload).to be_sent
      expect(reminder.failure_reason).to include("締め切りを過ぎた")
    end

    it "送信中のまま停止し何も送っていないものは、締め切り後に未送信へ戻すこと" do
      reminder = enable!(channel: "chat")
      stall!(reminder, at: jst.parse("2026-10-17 12:00"))

      dispatch_at(jst.parse("2026-10-18 06:05"))

      expect(reminder.reload).to be_pending
      expect(ChatMessage.count).to eq 0
    end

    it "送信中のまま停止した後に無効化されたものも引き継いで確定し、送信中のまま残さないこと" do
      reminder = enable!
      stall!(reminder, at: jst.parse("2026-10-17 12:00"))
      reminder.update_columns(enabled: false)

      dispatch_at(jst.parse("2026-10-17 12:20"))

      expect(reminder.reload).to be_pending
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "停止後15分以内の送信中は他の実行中とみなして触らないこと" do
      reminder = enable!
      stall!(reminder, at: jst.parse("2026-10-17 12:00"))

      dispatch_at(jst.parse("2026-10-17 12:10"))

      expect(reminder.reload).to be_sending
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "SMTPがエラー応答を返した宛先は未送信確定、応答待ちタイムアウトは結果不明として記録し、どちらも再送しないこと" do
      reminder = enable!
      allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now).and_wrap_original do |original, *args|
        recipient = original.receiver.message.to.first
        raise Net::SMTPAuthenticationError, "535 auth" if recipient == member_a.email
        raise Net::ReadTimeout if recipient == member_b.email

        original.call(*args)
      end

      dispatch_at(jst.parse("2026-10-17 12:00"))
      dispatch_at(jst.parse("2026-10-17 12:30"))

      expect(reminder.deliveries.find_by(customer: member_a).failure_reason).to start_with("[未送信確定] Net::SMTPAuthenticationError")
      expect(reminder.deliveries.find_by(customer: member_b).failure_reason).to start_with("[結果不明] Net::ReadTimeout")
      expect(reminder.deliveries.find_by(customer: owner)).to be_delivered
      expect(reminder.reload).to be_sent
      expect(EventDeadlineReminderDelivery.count).to eq 3
    end

    it "あるイベントで想定外のエラーが起きても、他のイベントのリマインドは送ること" do
      other_event = FactoryBot.create(
        :event, :event_with_songs,
        customer: owner, community: community,
        event_start_time: jst.parse("2026-10-26 18:00"),
        event_end_time: jst.parse("2026-10-26 21:00"),
        event_entry_deadline: jst.parse("2026-10-17 23:00")
      )
      broken = enable!
      travel_to(jst.parse("2026-10-17 08:00"))
      other_event.update!(deadline_reminders_attributes: [{ kind: "entry", enabled: "1", channel: "mail" }])
      allow(EventDeadlineReminders::RecipientResolver).to receive(:new).and_call_original
      allow(EventDeadlineReminders::RecipientResolver).to receive(:new).with(having_attributes(id: event.id)).and_raise(ActiveRecord::StatementInvalid, "boom")

      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(broken.reload).to be_failed
      expect(broken.failure_reason).to include("boom")
      expect(other_event.deadline_reminders.first.reload).to be_sent
      expect(ActionMailer::Base.deliveries.size).to eq 3
    end
  end
end
