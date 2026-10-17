require "rails_helper"

RSpec.describe EventDeadlineReminders::Dispatcher, "送信タイミング・送信メッセージの編集" do
  include ActiveSupport::Testing::TimeHelpers

  let(:jst) { Time.find_zone("Asia/Tokyo") }
  let(:owner) { FactoryBot.create(:customer, name: "主催者") }
  let(:community) { FactoryBot.create(:community, owner_id: owner.id) }
  let!(:member_a) { FactoryBot.create(:customer) }
  let!(:member_b) { FactoryBot.create(:customer) }
  let(:event) do
    FactoryBot.create(
      :event, :event_with_songs,
      customer: owner, community: community,
      event_name: "秋のセッション",
      event_start_time: jst.parse("2026-10-25 18:00"),
      event_end_time: jst.parse("2026-10-25 21:00"),
      event_entry_deadline: jst.parse("2026-10-17 23:59"),
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

  def enable!(kind: "entry", channel: "mail", **attributes)
    travel_to(jst.parse("2026-10-17 08:00"))
    event.update!(deadline_reminders_attributes: [{ kind: kind, enabled: "1", channel: channel }.merge(attributes)])
    event.deadline_reminders.reload.detect { |reminder| reminder.kind == kind }
  end

  def update_reminder!(reminder, **attributes)
    event.update!(deadline_reminders_attributes: [{ id: reminder.id }.merge(attributes)])
    reminder.reload
  end

  def dispatch_at(time)
    travel_to(time)
    described_class.call(now: Time.current)
  end

  def mail_text(mail)
    Nokogiri::HTML(mail.body.decoded).text
  end

  describe "送信タイミング" do
    it "設定した時間前(3時間前)になるまで送らず、なったら送ること" do
      reminder = enable!(lead_hours: "3")

      dispatch_at(jst.parse("2026-10-17 20:58"))
      expect(ActionMailer::Base.deliveries).to be_empty

      dispatch_at(jst.parse("2026-10-17 20:59"))
      expect(reminder.reload).to be_sent
      expect(ActionMailer::Base.deliveries.size).to eq 3
    end

    it "時間を短くして予定日時が未来に移れば、元の予定日時では送らないこと" do
      reminder = enable!
      update_reminder!(reminder, lead_hours: "2")

      dispatch_at(jst.parse("2026-10-17 12:00"))
      expect(reminder.reload).to be_pending
      expect(ActionMailer::Base.deliveries).to be_empty

      dispatch_at(jst.parse("2026-10-17 21:59"))
      expect(reminder.reload).to be_sent
    end

    it "時間の変更で予定日時が過去になったら、即送信しないこと" do
      reminder = enable!
      update_reminder!(reminder, lead_hours: "24")

      dispatch_at(jst.parse("2026-10-17 08:05"))

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(reminder.reload).to be_pending
      expect(reminder).to be_disarmed_by_lead_time_changed_past
    end

    it "定期処理が止まって予定日時を過ぎても、締め切り前なら次回実行で送ること(時間を変えた場合も同じ)" do
      reminder = enable!(lead_hours: "6")

      dispatch_at(jst.parse("2026-10-17 22:30"))

      expect(reminder.reload).to be_sent
    end

    it "本文だけを変えても送信予定は変わらず、予定どおり送ること" do
      reminder = enable!
      travel_to(jst.parse("2026-10-17 10:00"))
      update_reminder!(reminder, custom_message: "直前に本文だけ変更")

      dispatch_at(jst.parse("2026-10-17 11:59"))

      expect(reminder.reload).to be_sent
      expect(mail_text(ActionMailer::Base.deliveries.first)).to include("直前に本文だけ変更")
    end

    it "送信済みの後に時間や本文を変えても再送しないこと" do
      reminder = enable!
      dispatch_at(jst.parse("2026-10-17 12:00"))
      ActionMailer::Base.deliveries.clear
      travel_to(jst.parse("2026-10-17 12:10"))
      update_reminder!(reminder, lead_hours: "1", custom_message: "もう一度送りたい")

      dispatch_at(jst.parse("2026-10-17 23:00"))

      expect(ActionMailer::Base.deliveries).to be_empty
      expect(reminder.reload).to be_sent
    end
  end

  describe "送信メッセージ" do
    it "カスタム本文をメールで送り、件名は自動生成のまま、共通フッターのURLを付けること" do
      enable!(custom_message: "今週末が締め切りです🎸\n\n迷っている方もぜひ！")
      dispatch_at(jst.parse("2026-10-17 12:00"))

      mail = ActionMailer::Base.deliveries.first
      expect(mail.subject).to eq "【BeMyStyle】【本日締め切り🎸】秋のセッションのエントリー受付について"
      text = mail_text(mail)
      expect(text).to include("今週末が締め切りです🎸", "迷っている方もぜひ！")
      expect(text).not_to include("気になる曲や、挑戦してみたいパート")
      expect(mail.body.decoded).to include(%(href="https://be-my-style.com/public/events/#{event.id}"))
    end

    it "カスタム本文をコミュニティチャットへ自動お知らせとして投稿すること" do
      enable!(channel: "chat", custom_message: "<b>太字にならない</b>\nチャットでお知らせ")
      dispatch_at(jst.parse("2026-10-17 12:00"))

      message = ChatMessage.last
      expect(message).to be_system_generated
      html = Chat::MarkdownRenderer.call(message.content)
      expect(html).to include("&lt;b&gt;太字にならない&lt;/b&gt;")
      expect(html).to include(%(href="https://be-my-style.com/public/events/#{event.id}"))
    end

    it "カスタム本文を空に戻すと自動生成の文章で送ること" do
      reminder = enable!(custom_message: "一度書いた本文")
      update_reminder!(reminder, custom_message: "")

      dispatch_at(jst.parse("2026-10-17 12:00"))

      expect(mail_text(ActionMailer::Base.deliveries.first)).to include("気になる曲や、挑戦してみたいパート")
    end

    it "編集画面のプレビューと実際に送信される件名・本文が一致すること" do
      reminder = enable!(custom_message: "プレビューと同じ本文")
      preview = EventDeadlineReminders::FormPreview.new(event: event.reload, reminder: event.deadline_reminder_for(:entry))
      expected = preview.message

      dispatch_at(jst.parse("2026-10-17 11:59"))

      mail = ActionMailer::Base.deliveries.first
      expect(mail.subject).to eq "【BeMyStyle】#{expected.subject}"
      expect(reminder.reload.message_snapshot["body"]).to eq expected.body
      expected.body.split("\n").reject(&:blank?).each { |line| expect(mail_text(mail)).to include(line) }
    end
  end

  describe "配信中の設定変更" do
    it "停止後に別の実行が引き継いでも、配信開始時に確定した本文で残りの受信者へ送ること" do
      reminder = enable!(custom_message: "配信開始時の本文")
      travel_to(jst.parse("2026-10-17 12:00"))
      reminder.update_columns(status: EventDeadlineReminder.statuses[:sending], started_at: Time.current)
      reminder.message_snapshot!(now: Time.current)
      reminder.deliveries.create!(customer: owner, status: :delivered, delivered_at: Time.current)
      # 画面の検証をすり抜けて送信中に設定が変わった場合(競合)を再現する。
      reminder.update_columns(custom_message: "途中で変えた本文", channel: EventDeadlineReminder.channels[:chat])

      dispatch_at(jst.parse("2026-10-17 12:20"))

      texts = ActionMailer::Base.deliveries.map { |mail| mail_text(mail) }
      expect(ActionMailer::Base.deliveries.map(&:to)).to contain_exactly([member_a.email], [member_b.email])
      expect(texts).to all(include("配信開始時の本文"))
      expect(texts.join).not_to include("途中で変えた本文")
      expect(ChatMessage.count).to eq 0
      expect(reminder.reload).to be_sent
    end

    it "1回の実行の中では、送信途中に本文が変わっても全員に同じ本文を送ること" do
      reminder = enable!(custom_message: "最初の本文")
      original = EventDeadlineReminderMailer.method(:with)
      changed = false
      allow(EventDeadlineReminderMailer).to receive(:with) do |params|
        unless changed
          changed = true
          EventDeadlineReminder.where(id: reminder.id).update_all(custom_message: "送信中に変更")
        end
        original.call(params)
      end

      dispatch_at(jst.parse("2026-10-17 12:00"))

      texts = ActionMailer::Base.deliveries.map { |mail| mail_text(mail) }
      expect(texts.size).to eq 3
      expect(texts).to all(include("最初の本文"))
    end

    it "確保後に送れないと分かり未送信へ戻した場合は、確定した本文を破棄すること" do
      reminder = enable!
      travel_to(jst.parse("2026-10-17 12:00"))
      reminder.update_columns(status: EventDeadlineReminder.statuses[:sending], started_at: Time.current)
      reminder.message_snapshot!(now: Time.current)

      dispatch_at(jst.parse("2026-10-18 00:30"))

      expect(reminder.reload).to be_pending
      expect(reminder.message_snapshot).to be_nil
    end
  end
end
